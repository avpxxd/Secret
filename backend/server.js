const express = require('express');
const cors = require('cors');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { Server } = require('socket.io');

const API_PORT = Number(process.env.PORT || 3001);
const SOCKET_PORTS = [7100, 7101, 7102, 7103, 7150, 7151, 7152, 7153];
const PUBLIC_HOST = process.env.PUBLIC_HOST || 'localhost';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const users = new Map();
const liveEvents = [];
const connections = new Map();
const servers = [];
const planeRecords = new Map();
const planeOrder = [];

const geoPath = path.join(__dirname, '..', 'assets', 'data', '_geo.json');
const geoData = JSON.parse(fs.readFileSync(geoPath, 'utf8'));

function now() {
  return new Date().toISOString();
}

function makeConnectionId(port, socketId) {
  return `${port}:${socketId}`;
}

function normalizePayload(payload) {
  if (payload && typeof payload === 'object' && payload.d !== undefined) {
    return payload.d;
  }
  return payload;
}

function upsertUserFromPayload(payload, socketMeta) {
  if (!payload || typeof payload !== 'object') {
    return null;
  }

  const userId = payload.id || payload.userId || socketMeta.userId || socketMeta.socketId;
  const current = users.get(userId) || {
    id: userId,
    createdAt: now(),
    lastSeen: now()
  };

  const merged = {
    ...current,
    ...payload,
    id: userId,
    socketId: socketMeta.socketId,
    port: socketMeta.port,
    type: socketMeta.type,
    experience: socketMeta.experience,
    lastSeen: now()
  };

  users.set(userId, merged);
  return merged;
}

function addLiveEvent(kind, payload, meta) {
  const event = {
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    kind,
    payload,
    meta,
    createdAt: now()
  };
  liveEvents.push(event);
  while (liveEvents.length > 500) {
    liveEvents.shift();
  }
  return event;
}

function planeOwnerKey(data) {
  if (!data || typeof data !== 'object') {
    return 'global';
  }
  if (data.subscriptionId !== undefined && data.subscriptionId !== null && data.subscriptionId !== -1) {
    return `subscription:${data.subscriptionId}`;
  }
  if (data.client) {
    return `client:${data.client}`;
  }
  if (data.pool) {
    return `pool:${data.pool}`;
  }
  return 'global';
}

function storedPlaneCount(ownerKey) {
  let count = 0;
  for (const plane of planeRecords.values()) {
    if (plane.ownerKey === ownerKey) {
      count += 1;
    }
  }
  return count;
}

function serializePlaneRecord(record) {
  return {
    id: record.id,
    type: 'planes',
    data: typeof record.data === 'string' ? record.data : JSON.stringify(record.data),
    count: record.count,
    pool: record.pool,
    subscriptionId: record.subscriptionId,
    lastUpdated: record.lastUpdated,
    client: record.client
  };
}

function upsertPlaneRecord(payload) {
  const id = payload.id || payload.__saveId || `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const data = typeof payload.data === 'string' ? JSON.parse(payload.data) : (payload.data || payload);
  const ownerKey = planeOwnerKey(data);
  const count = storedPlaneCount(ownerKey) + (planeRecords.has(id) ? 0 : 1);
  const record = {
    id,
    ownerKey,
    data,
    count,
    pool: data.pool || payload.pool || 'world',
    subscriptionId: data.subscriptionId !== undefined ? data.subscriptionId : payload.subscriptionId,
    lastUpdated: data.lastUpdated || payload.lastUpdated || Date.now(),
    client: data.client || payload.client || 'web'
  };
  planeRecords.set(id, record);
  if (!planeOrder.includes(id)) {
    planeOrder.push(id);
  }
  return record;
}

function findPlaneByPool(pool) {
  const matches = [];
  for (const record of planeRecords.values()) {
    if (!pool || pool === 'world' || record.pool === pool || (pool === 'east' && record.pool === 'east') || (pool === 'west' && record.pool === 'west')) {
      matches.push(record);
    }
  }
  if (!matches.length) {
    return null;
  }
  return matches[matches.length > 1 ? Math.floor(Math.random() * matches.length) : 0];
}

function broadcast(eventName, payload, excludeSocket) {
  for (const entry of connections.values()) {
    if (excludeSocket && entry.socketId === excludeSocket.id) {
      continue;
    }
    entry.socket.emit(eventName, { d: payload });
  }
}

function registerSocket(socket, port) {
  const meta = {
    socketId: socket.id,
    port,
    type: null,
    experience: null,
    userId: null,
    connectedAt: now(),
    lastSeen: now()
  };

  connections.set(makeConnectionId(port, socket.id), {
    ...meta,
    socket
  });

  socket.emit('r', {
    d: {
      type: 'welcome',
      port,
      time: now()
    }
  });

  socket.on('i', payload => {
    const entry = connections.get(makeConnectionId(port, socket.id));
    if (!entry) {
      return;
    }

    entry.type = payload && payload.t ? payload.t : entry.type;
    entry.experience = payload && payload.x ? payload.x : entry.experience;
    entry.lastSeen = now();
    entry.userId = payload && (payload.userId || payload.id) ? (payload.userId || payload.id) : entry.userId;

    if (payload && typeof payload === 'object') {
      upsertUserFromPayload(payload.user || payload, entry);
    }

    socket.emit('ev', {
      d: {
        type: 'connected',
        port,
        socketId: socket.id,
        timestamp: now()
      }
    });
  });

  socket.on('s', payload => {
    const entry = connections.get(makeConnectionId(port, socket.id));
    if (!entry) {
      return;
    }

    entry.lastSeen = now();
    const data = normalizePayload(payload);
    if (data && typeof data === 'object') {
      upsertUserFromPayload(data.user || data, entry);
    }
    addLiveEvent('message', data, {
      port,
      socketId: socket.id,
      type: entry.type,
      experience: entry.experience
    });
    broadcast('r', data, socket);
  });

  socket.on('event', payload => {
    const entry = connections.get(makeConnectionId(port, socket.id));
    if (!entry) {
      return;
    }

    entry.lastSeen = now();
    const data = normalizePayload(payload);
    addLiveEvent('event', data, {
      port,
      socketId: socket.id,
      type: entry.type,
      experience: entry.experience
    });
    broadcast('ev', data, socket);
  });

  socket.on('side', payload => {
    const entry = connections.get(makeConnectionId(port, socket.id));
    if (!entry) {
      return;
    }

    entry.lastSeen = now();
    const data = normalizePayload(payload);
    addLiveEvent('side', data, {
      port,
      socketId: socket.id,
      type: entry.type,
      experience: entry.experience
    });
    broadcast('sideMsg', data, socket);
  });

  socket.on('disconnect', () => {
    connections.delete(makeConnectionId(port, socket.id));
  });
}

function createSocketPort(port) {
  const server = http.createServer((req, res) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');
    res.end('Paper Planes socket server');
  });

  const io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST']
    }
  });

  io.on('connection', socket => registerSocket(socket, port));

  server.listen(port, () => {
    console.log(`socket server listening on ${port}`);
  });

  servers.push({ port, server, io });
}

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    time: now(),
    sockets: SOCKET_PORTS.length,
    users: users.size,
    liveEvents: liveEvents.length
  });
});

app.get('/geo', (req, res) => {
  res.json(geoData);
});

app.get('/select', (req, res) => {
  const pool = req.query.pool || 'world';
  const plane = findPlaneByPool(pool);
  if (!plane) {
    res.json({ fail: true, pool: 'nopool' });
    return;
  }
  res.json(serializePlaneRecord(plane));
});

app.get('/getData', (req, res) => {
  const id = req.query.id;
  if (!id || !planeRecords.has(id)) {
    res.json({ fail: true, data: null });
    return;
  }
  res.json(serializePlaneRecord(planeRecords.get(id)));
});

app.post('/setData', (req, res) => {
  const payload = req.body || {};
  const record = upsertPlaneRecord(payload);
  res.json({
    ok: true,
    id: record.id,
    count: record.count
  });
});

app.get('/active_servers.json', (req, res) => {
  const ports = {};
  for (const port of SOCKET_PORTS) {
    ports[String(port)] = connections.size;
  }

  res.json({
    'local': {
      host: PUBLIC_HOST,
      coords: [34.052234, -118.243685],
      ports
    }
  });
});

app.get('/api/users', (req, res) => {
  res.json(Array.from(users.values()));
});

app.get('/api/users/:id', (req, res) => {
  const user = users.get(req.params.id);
  if (!user) {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  res.json(user);
});

app.post('/api/users', (req, res) => {
  const payload = req.body || {};
  const userId = payload.id || payload.userId;
  if (!userId) {
    res.status(400).json({ error: 'Missing id' });
    return;
  }

  const user = {
    id: userId,
    ...payload,
    lastSeen: now()
  };
  users.set(userId, user);
  res.json(user);
});

app.get('/api/live', (req, res) => {
  res.json(liveEvents.slice(-200));
});

app.post('/api/live', (req, res) => {
  const event = addLiveEvent('manual', req.body || {}, { source: 'http' });
  res.status(201).json(event);
});

app.listen(API_PORT, () => {
  console.log(`api server listening on ${API_PORT}`);
});

for (const port of SOCKET_PORTS) {
  createSocketPort(port);
}
