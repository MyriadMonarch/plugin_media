#!/usr/bin/env node

const http = require('http');
const https = require('https');

const PORT = parseInt(process.argv[2] || '5051', 10);
const AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0';

function fetch(uri, opts = {}) {
  return new Promise((resolve, reject) => {
    const mod = uri.startsWith('https') ? https : http;
    const headers = { 'User-Agent': AGENT, ...opts.headers };
    const req = mod.get(uri, { headers, timeout: 20000 }, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', () => resolve({ status: res.statusCode, body: data, headers: res.headers }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
  });
}

function postJSON(uri, data) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(data);
    const u = new URL(uri);
    const mod = uri.startsWith('https') ? https : http;
    const req = mod.request(uri, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        'User-Agent': AGENT,
        'Accept': 'application/json',
      },
      timeout: 20000,
    }, (res) => {
      let d = '';
      res.on('data', (c) => d += c);
      res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.write(body);
    req.end();
  });
}

function json(res, data, status = 200) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function error(res, msg, status = 500) {
  json(res, { error: msg }, status);
}

// ── AniList GraphQL search ───────────────────────────────────────────────────

async function anilistSearch(query) {
  const ql = {
    query: `query ($q: String) {
      Page(page: 1, perPage: 25) {
        media(search: $q, type: ANIME) {
          id title { romaji english native }
          coverImage { large medium }
          format status episodes genres
          averageScore description
        }
      }
    }`,
    variables: { q: query },
  };
  const { body } = await postJSON('https://graphql.anilist.co', ql);
  const data = JSON.parse(body);
  const media = data?.data?.Page?.media || [];
  return media.map((m) => ({
    source: 'JUSTALANIME',
    title: m.title?.english || m.title?.romaji || m.title?.native || '?',
    alt_titles: [m.title?.romaji, m.title?.native].filter(Boolean),
    id: String(m.id),
    image: m.coverImage?.large || m.coverImage?.medium || '',
    format: m.format || '',
    status: m.status || '',
    episodes: m.episodes || 0,
    genres: m.genres || [],
    score: m.averageScore || 0,
    description: (m.description || '').replace(/<[^>]*>/g, ''),
  }));
}

// ── AniList GraphQL popular ───────────────────────────────────────────────

async function anilistPopular(page = 1, perPage = 20) {
  const ql = {
    query: `query ($page: Int, $perPage: Int) {
      Page(page: $page, perPage: $perPage) {
        media(sort: POPULARITY_DESC, type: ANIME) {
          id title { romaji english native }
          coverImage { large medium }
          format status episodes genres
          averageScore description
        }
      }
    }`,
    variables: { page, perPage },
  };
  const { body } = await postJSON('https://graphql.anilist.co', ql);
  const data = JSON.parse(body);
  const media = data?.data?.Page?.media || [];
  return media.map((m) => ({
    id: String(m.id),
    title: m.title,
    coverImage: m.coverImage,
    format: m.format || '',
    status: m.status || '',
    episodes: m.episodes || 0,
    genres: m.genres || [],
    averageScore: m.averageScore || 0,
    description: (m.description || '').replace(/<[^>]*>/g, ''),
  }));
}

// ── Animeflv episode list ────────────────────────────────────────────────────

async function animeflvEpisodes(slug) {
  const { body } = await fetch(`https://www4.animeflv.net/anime/${encodeURIComponent(slug)}`);
  const m = body.match(/var\s+episodes\s*=\s*(\[\[.*?\]\]);/);
  if (!m) return [];
  const eps = JSON.parse(m[1]);
  return eps.map(([num]) => String(num));
}

async function animeflvStreamLinks(slug, ep) {
  const { body } = await fetch(`https://www4.animeflv.net/ver/${encodeURIComponent(slug)}-${ep}`);
  const m = body.match(/var\s+videos\s*=\s*(\{.*?\});/);
  if (!m) return [];
  const codes = [...m[1].matchAll(/"code"\s*:\s*"([^"]+)"/g)].map(x => x[1].replace(/\\\//g, '/'));
  return codes.map((url, i) => ({
    quality: 'best',
    url,
    type: 'embed',
    provider: 'ANIMEFLV',
  }));
}

// ── Embed → direct URL resolvers ─────────────────────────────────────────────
// Most embed URLs are passed through as-is for MPV+yt-dlp to resolve.
// Only mega.nz gets converted to a loadable format here.

async function resolveMegaEmbed(url) {
  const m = url.match(/embed[!/#]+([^/\s?]+)/);
  if (m) return [{ quality: 'best', url: `https://mega.nz/#!${m[1]}`, type: 'embed', provider: 'MEGA' }];
  return [];
}

// ── Gogoanime (multiple mirrors) ─────────────────────────────────────────────

const GOGO = ['https://gogoanime3.co', 'https://anitaku.to'];

async function gogoEpisodes(slug) {
  for (const base of GOGO) {
    try {
      const { body } = await fetch(`${base}/category/${encodeURIComponent(slug)}`);
      if (body.includes('window.location.replace')) continue;
      const eps = [...body.matchAll(/episode-(\d+)/g)]
        .map(x => parseInt(x[1], 10))
        .filter((v, i, a) => a.indexOf(v) === i)
        .sort((a, b) => a - b);
      if (eps.length) return eps.map(String);
    } catch {}
  }
  return [];
}

async function gogoStreamLinks(id, ep) {
  for (const base of GOGO) {
    try {
      const uri = `${base}/${id}-episode-${ep}`;
      const { body } = await fetch(uri);
      if (body.includes('window.location.replace')) continue;
      const dv = body.match(/data-video\s*=\s*['"]([^'"]+)['"]/);
      if (!dv) continue;
      let embedUrl = dv[1];
      if (embedUrl.startsWith('//')) embedUrl = 'https:' + embedUrl;
      if (!embedUrl.startsWith('http')) embedUrl = 'https://' + embedUrl;
      const { body: eb } = await fetch(embedUrl, { headers: { Referer: uri } });
      const links = [];
      const m3u8 = eb.match(/file\s*:\s*['"]([^'"]*\.m3u8[^'"]*)['"]/);
      if (m3u8) links.push({ quality: 'best', url: m3u8[1], type: 'm3u8', provider: 'GOGOANIME' });
      const mp4 = eb.match(/file\s*:\s*['"]([^'"]*\.mp4[^'"]*)['"]/);
      if (mp4) links.push({ quality: '720p', url: mp4[1], type: 'mp4', provider: 'GOGOANIME' });
      if (links.length) return links;
    } catch {}
  }
  return [];
}

// ── Router ───────────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = u.pathname;
  const query = Object.fromEntries(u.searchParams.entries());

  try {
    if (pathname === '/health') {
      return json(res, { status: 'ok' });
    }

    if (pathname === '/search') {
      const q = (query.q || '').trim();
      if (!q) return error(res, 'Missing q param', 400);
      const results = await anilistSearch(q);
      return json(res, { query: q, count: results.length, results });
    }

    if (pathname === '/info') {
      const id = (query.id || '').trim();
      if (!id) return error(res, 'Missing id param', 400);
      const ql = {
        query: `query ($id: Int) {
          Media(id: $id, type: ANIME) {
            id title { romaji english native }
            coverImage { large medium }
            description averageScore episodes genres status
          }
        }`,
        variables: { id: parseInt(id, 10) },
      };
      const { body } = await postJSON('https://graphql.anilist.co', ql);
      const data = JSON.parse(body);
      const m = data?.data?.Media;
      if (!m) return json(res, { error: 'not found' }, 404);
      return json(res, {
        result: {
          ...m,
          description: (m.description || '').replace(/<[^>]*>/g, ''),
        }
      });
    }

    if (pathname === '/popular') {
      const page = parseInt(query.page || '1', 10);
      const size = parseInt(query.size || '20', 10);
      const results = await anilistPopular(page, size);
      return json(res, { page, size, total: results.length, count: results.length, results });
    }

    if (pathname === '/stream') {
      const q = (query.q || '').trim();
      const ep = query.ep || '';
      if (!q || !ep) return error(res, 'Missing q or ep param', 400);
      let results = await gogoStreamLinks(q, ep);
      if (!results.length) {
        results = await animeflvStreamLinks(q, ep);
        // Convert mega.nz embeds; other embeds pass through for MPV+yt-dlp
        for (let i = 0; i < results.length; i++) {
          if (results[i].url.includes('mega.nz')) {
            const mega = await resolveMegaEmbed(results[i].url);
            if (mega.length) results[i] = mega[0];
          }
        }
      }
      return json(res, { query: q, episode: ep, count: results.length, results });
    }

    if (pathname === '/episodes') {
      const q = (query.q || '').trim();
      if (!q) return error(res, 'Missing q param', 400);
      let eps = await animeflvEpisodes(q);
      if (!eps.length) eps = await gogoEpisodes(q);
      return json(res, { id: q, count: eps.length, episodes: eps });
    }

    if (pathname === '/download') {
      const q = (query.q || '').trim();
      const ep = query.ep || '';
      if (!q || !ep) return error(res, 'Missing q or ep param', 400);
      const results = await gogoStreamLinks(q, ep);
      return json(res, { query: q, episode: ep, count: results.length, results });
    }

    return error(res, 'Not found', 404);

  } catch (e) {
    console.error('[justalanime]', e.message);
    return error(res, e.message);
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[justalanime] Listening on http://127.0.0.1:${PORT}`);
});
