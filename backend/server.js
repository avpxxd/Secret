const express = require('express');
const cors = require('cors');
const http = require('http');
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
