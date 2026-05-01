/**
 * Superpowers plugin for OpenCode.ai
 *
 * Injects superpowers bootstrap context via system prompt transform.
 * Auto-registers skills directory via config hook (no symlinks needed).
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Simple YAML frontmatter parser (avoids dependency on skills-core for bootstrap).
// Handles flat k:v, nested objects via indentation, literal block scalars (|),
// type coercion (number, boolean, null), and quoted keys.
const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };

  const lines = match[1].split('\n');
  const body = match[2];

  const parseValue = (raw) => {
    const v = raw.trim();
    if (v === 'true') return true;
    if (v === 'false') return false;
    if (v === 'null') return null;
    if (/^\d+(\.\d+)?$/.test(v)) return Number(v);
    return v.replace(/^["']|["']$/g, '');
  };

  const parseBlock = (start, parentIndent) => {
    const obj = {};
    let i = start;
    while (i < lines.length) {
      const line = lines[i];
      if (!line.trim() || line.trim().startsWith('#')) { i++; continue; }

      const indent = line.search(/\S/);
      if (indent <= parentIndent) break;

      const colon = line.indexOf(':', indent);
      if (colon === -1) { i++; continue; }

      const key = line.slice(indent, colon).trim().replace(/^["']|["']$/g, '');
      const rest = line.slice(colon + 1);

      if (rest.trim() === '|') {
        const blockLines = [];
        i++;
        while (i < lines.length) {
          const nl = lines[i];
          const ni = nl.search(/\S/);
          if (ni <= indent && nl.trim()) break;
          blockLines.push(nl.slice(indent + 2) || '');
          i++;
        }
        const lastNonEmpty = blockLines.length - 1;
        let end = lastNonEmpty;
        while (end >= 0 && blockLines[end] === '') end--;
        obj[key] = blockLines.slice(0, end + 1).join('\n');
      } else if (!rest.trim()) {
        i++;
        const { result, nextIdx } = parseBlockInner(i, indent);
        obj[key] = result;
        i = nextIdx;
      } else {
        obj[key] = parseValue(rest);
        i++;
      }
    }
    return { result: obj, nextIdx: i };
  };

  // Wrapper because parseBlock is recursive and we need to separate start from parentIndent
  const parseBlockInner = (start, parentIndent) => parseBlock(start, parentIndent);

  const { result } = parseBlock(0, -1);
  return { frontmatter: result, content: body };
};

// Normalize a path: trim whitespace, expand ~, resolve to absolute
const normalizePath = (p, homeDir) => {
  if (!p || typeof p !== 'string') return null;
  let normalized = p.trim();
  if (!normalized) return null;
  if (normalized.startsWith('~/')) {
    normalized = path.join(homeDir, normalized.slice(2));
  } else if (normalized === '~') {
    normalized = homeDir;
  }
  return path.resolve(normalized);
};

const stripJsonComments = (content) => content
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/^\s*\/\/.*$/gm, '');

const isPlainObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

const deepMerge = (base, override) => {
  if (!isPlainObject(base) || !isPlainObject(override)) {
    return override;
  }

  const merged = { ...base };
  for (const [key, value] of Object.entries(override)) {
    if (isPlainObject(value) && isPlainObject(merged[key])) {
      merged[key] = deepMerge(merged[key], value);
      continue;
    }
    merged[key] = value;
  }
  return merged;
};

// Read agent definitions from markdown files in the agents directory.
// Each file follows the OpenCode agent markdown format:
//   - filename (without .md) = agent name
//   - YAML frontmatter = metadata (description, mode, temperature, permission, etc.)
//   - body = system prompt
const loadAgentsFromDirectory = (agentsDir) => {
  const agents = {};
  if (!fs.existsSync(agentsDir)) return agents;

  const files = fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'));
  for (const file of files) {
    const filePath = path.join(agentsDir, file);
    const content = fs.readFileSync(filePath, 'utf8');
    const { frontmatter, content: body } = extractAndStripFrontmatter(content);
    if (!frontmatter.description) continue;

    const name = path.basename(file, '.md');
    agents[name] = {
      ...frontmatter,
      prompt: body.trim(),
    };
  }
  return agents;
};

const DEFAULT_SUPERPOWERS_CONFIG = `{
  // Superpowers-specific OpenCode overrides.
  // Edit models here instead of creating agent entries manually in opencode.json.
  "agent": {
    "implementer-sp": {
      // "model": "anthropic/claude-sonnet-4-6"
    },
    "spec-reviewer-sp": {
      // "model": "anthropic/claude-sonnet-4-6"
    },
    "code-reviewer-sp": {
      // "model": "anthropic/claude-opus-4-6"
    }
  }
}
`;

export const SuperpowersPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();
  const superpowersSkillsDir = path.resolve(__dirname, '../../skills');
  // const superpowersSkillsDir = path.resolve(__dirname, './superpowers/skills');
  const envConfigDir = normalizePath(process.env.OPENCODE_CONFIG_DIR, homeDir);
  const configDir = envConfigDir || path.join(homeDir, '.config/opencode');
  const superpowersConfigPath = path.join(configDir, 'superpowers.jsonc');

  const ensureSuperpowersConfig = () => {
    if (fs.existsSync(superpowersConfigPath)) return;
    fs.mkdirSync(path.dirname(superpowersConfigPath), { recursive: true });
    fs.writeFileSync(superpowersConfigPath, DEFAULT_SUPERPOWERS_CONFIG, 'utf8');
  };

  const loadSuperpowersConfig = () => {
    ensureSuperpowersConfig();

    try {
      const rawContent = fs.readFileSync(superpowersConfigPath, 'utf8');
      const parsed = JSON.parse(stripJsonComments(rawContent));
      return isPlainObject(parsed) ? parsed : {};
    } catch (error) {
      console.warn(`[superpowers] Failed to parse ${superpowersConfigPath}: ${error.message}`);
      return {};
    }
  };

  // Helper to generate bootstrap content
  const getBootstrapContent = () => {
    // Try to load using-superpowers skill
    const skillPath = path.join(superpowersSkillsDir, 'using-superpowers', 'SKILL.md');
    if (!fs.existsSync(skillPath)) return null;

    const fullContent = fs.readFileSync(skillPath, 'utf8');
    const { content } = extractAndStripFrontmatter(fullContent);

    const toolMapping = `**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → \`todowrite\`
- \`Task\` tool with subagents → Use OpenCode's subagent system (@mention)
- \`Skill\` tool → OpenCode's native \`skill\` tool
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Your native tools

Use OpenCode's native \`skill\` tool to list and load skills.`;

    return `<EXTREMELY_IMPORTANT>
You have superpowers.

**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT use the skill tool to load "using-superpowers" again - that would be redundant.**

${content}

${toolMapping}
</EXTREMELY_IMPORTANT>`;
  };

  return {
    // Inject skills path into live config so OpenCode discovers superpowers skills
    // without requiring manual symlinks or config file edits.
    // This works because Config.get() returns a cached singleton — modifications
    // here are visible when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(superpowersSkillsDir)) {
        config.skills.paths.push(superpowersSkillsDir);
      }

      const superpowersConfig = loadSuperpowersConfig();
      const mergedConfig = deepMerge(config, superpowersConfig);
      const agents = mergedConfig.agent || {};
      const userOverrides = superpowersConfig.agent || {};

      // Load agents from agents/ directory. Format follows OpenCode agent markdown standard:
      // frontmatter (description, mode, permission, etc.) + body (system prompt).
      // User overrides from superpowers.jsonc are merged on top so they always win.
      const agentsDir = path.resolve(__dirname, '../../agents');
      // const agentsDir = path.resolve(__dirname, './superpowers/agents');

      const fileAgents = loadAgentsFromDirectory(agentsDir);

      for (const [name, fileConfig] of Object.entries(fileAgents)) {
        agents[name] = {
          ...fileConfig,
          ...(userOverrides[name] || {}),
        };
      }

      Object.assign(config, mergedConfig, { agent: agents });
    },

    // Inject bootstrap into the first user message of each session.
    // Using a user message instead of a system message avoids:
    //   1. Token bloat from system messages repeated every turn (#750)
    //   2. Multiple system messages breaking Qwen and other models (#894)
    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;
      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;
      // Only inject once
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'))) return;
      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    },
  };
};
