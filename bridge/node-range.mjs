// Does a Node version satisfy a package's `engines.node` range? The subset of npm's
// range syntax packages use for `engines`: `||` alternatives of space-separated
// comparators (`>=`, `>`, `<=`, `<`, `=`, bare), `^` and `~` ranges, `x` wildcards.
// Anything else throws: an unreadable range is reported, never guessed at.

function parse(version, range) {
  const match = /^v?(\d+|[xX*])(?:\.(\d+|[xX*]))?(?:\.(\d+|[xX*]))?$/.exec(version);
  if (match === null) throw new Error(`cannot read version ${JSON.stringify(version)} in engines range ${JSON.stringify(range)}`);
  return match.slice(1).map((part) => (part === undefined || /^[xX*]$/.test(part) ? undefined : Number(part)));
}

function compare(a, b) {
  for (let i = 0; i < 3; i += 1) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
  return 0;
}

// A partial version as the [lower, upper) interval it stands for: 22 -> [22.0.0, 23.0.0).
function interval(parts) {
  const [major, minor, patch] = parts;
  if (major === undefined) return [[0, 0, 0], undefined];
  if (minor === undefined) return [[major, 0, 0], [major + 1, 0, 0]];
  if (patch === undefined) return [[major, minor, 0], [major, minor + 1, 0]];
  return [[major, minor, patch], [major, minor, patch + 1]];
}

function comparator(token, range) {
  const match = /^(\^|~|>=|<=|>|<|=)?(.+)$/.exec(token);
  const [, operator = '=', version] = match;
  const parts = parse(version, range);
  const [lower, upper] = interval(parts);
  const full = parts.map((part) => part ?? 0);
  switch (operator) {
    case '=':
      return (v) => compare(v, lower) >= 0 && (upper === undefined || compare(v, upper) < 0);
    case '>=':
      return (v) => compare(v, full) >= 0;
    case '>':
      return (v) => (upper === undefined ? false : compare(v, upper) >= 0);
    case '<':
      return (v) => compare(v, full) < 0;
    case '<=':
      return (v) => upper === undefined || compare(v, upper) < 0;
    case '^': {
      const [major, minor, patch] = full;
      const ceiling = major > 0 || parts[1] === undefined ? [major + 1, 0, 0] : minor > 0 || parts[2] === undefined ? [0, minor + 1, 0] : [0, 0, patch + 1];
      return (v) => compare(v, full) >= 0 && compare(v, ceiling) < 0;
    }
    case '~': {
      const ceiling = parts[1] === undefined ? [full[0] + 1, 0, 0] : [full[0], full[1] + 1, 0];
      return (v) => compare(v, full) >= 0 && compare(v, ceiling) < 0;
    }
    default:
      throw new Error(`cannot read engines range ${JSON.stringify(range)}`);
  }
}

export function satisfies(version, range) {
  if (typeof range !== 'string' || range.trim() === '') throw new Error(`cannot read engines range ${JSON.stringify(range)}`);
  const current = parse(version, range).map((part) => part ?? 0);
  return range.split('||').some((alternative) => {
    const tokens = alternative.trim().replace(/(>=|<=|>|<|=|\^|~)\s+/g, '$1').split(/\s+/);
    if (tokens.length === 1 && tokens[0] === '') throw new Error(`cannot read engines range ${JSON.stringify(range)}`);
    if (tokens.includes('-')) throw new Error(`hyphen ranges are not supported in engines range ${JSON.stringify(range)}`);
    return tokens.map((token) => comparator(token, range)).every((test) => test(current));
  });
}
