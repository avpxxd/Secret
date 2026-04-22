(function(window) {
  console.log("[PaperPlanes] Firebase bridge script loaded");
  var state = {
    initialized: false,
    db: null,
    useRest: false,
    socketRef: null,
    socketHandlers: [],
    liveHandlers: [],
    authReady: null,
    planeBags: {}
  };

  function hasConfig() {
    var config = window.FIREBASE_CONFIG || {};
    return !!(config.apiKey && config.authDomain && config.databaseURL && config.projectId && config.appId && config.apiKey.indexOf("YOUR_") !== 0);
  }

  function init() {
    if (state.initialized) {
      console.log("[PaperPlanes] Firebase bridge init skipped (already initialized)");
      return true;
    }
    console.log("[PaperPlanes] Firebase bridge init checking config", window.FIREBASE_CONFIG || null);
    if (!hasConfig()) {
      console.log("[PaperPlanes] Firebase bridge init failed (missing config)");
      return false;
    }
    if (!window.firebase || !firebase.database) {
      console.log("[PaperPlanes] Firebase bridge init failed (firebase SDK unavailable)");
      return false;
    }
    if (!firebase.apps || !firebase.apps.length) {
      firebase.initializeApp(window.FIREBASE_CONFIG);
    }
    state.db = firebase.database();
    state.useRest = false;
    state.initialized = true;
    console.log("[PaperPlanes] Firebase bridge init ready", { useRest: state.useRest });
    window.FirebasePlanesBridgeReady = true;
    return true;
  }

  function ensureReady() {
    init();
    return state.authReady || Promise.resolve(true);
  }

  function databaseBaseUrl() {
    var config = window.FIREBASE_CONFIG || {};
    return (config.databaseURL || "").replace(/\/$/, "");
  }

  function restRequest(path, method, body) {
    var url = databaseBaseUrl() + "/" + path + ".json";
    var options = {
      method: method || "GET",
      headers: {
        "Content-Type": "application/json"
      }
    };
    if (body !== undefined) {
      options.body = JSON.stringify(body);
    }
    console.log("[PaperPlanes] RTDB request", method || "GET", path, body !== undefined ? body : null);
    return fetch(url, options).then(function(response) {
      return response.text().then(function(text) {
        var data = null;
        if (text) {
          try {
            data = JSON.parse(text);
          } catch (error) {
            data = text;
          }
        }
        console.log("[PaperPlanes] RTDB response", method || "GET", path, response.status, data);
        if (!response.ok) {
          throw new Error((data && data.error) || response.statusText || "Firebase REST request failed");
        }
        return data;
      }).catch(function(error) {
        console.error("[PaperPlanes] RTDB response parse failed", method || "GET", path, error && error.message ? error.message : error);
        throw error;
      });
    }).catch(function(error) {
      console.error("[PaperPlanes] RTDB request failed", method || "GET", path, error && error.message ? error.message : error);
      throw error;
    });
  }

  function restGetPlaneCount() {
    return restRequest("meta/planeCount", "GET").then(function(metaCount) {
      metaCount = metaCount || 0;
      return restRequest("planes", "GET").then(function(value) {
        value = value || {};
        var actualCount = Object.keys(value).length;
        var count = Math.max(metaCount, actualCount);
        if (count !== metaCount) {
          return restRequest("meta/planeCount", "PUT", count).then(function() {
            return count;
          });
        }
        return count;
      });
    }).catch(function() {
      return 0;
    });
  }

  function restSavePlane(data, id, isNew) {
    var payload = clone(data);
    payload.id = id;
    payload.data = JSON.stringify(payload);
    payload.updatedAt = Date.now();
    if (!payload.createdAt) {
      payload.createdAt = payload.updatedAt;
    }
    return restRequest("planes/" + id, "PUT", payload).then(function() {
      var latestPayload = {
        id: id,
        pool: payload.pool || null,
        updatedAt: payload.updatedAt,
        createdAt: payload.createdAt
      };
      var debugPayload = {
        id: id,
        isNew: !!isNew,
        pool: payload.pool || null,
        updatedAt: payload.updatedAt,
        createdAt: payload.createdAt,
        client: payload.client || null
      };
      if (isNew) {
        return restGetPlaneCount().then(function(count) {
          return Promise.all([
            restRequest("meta/latestPlane", "PUT", latestPayload),
            restRequest("meta/planeCount", "PUT", count + 1),
            restRequest("debug/planeCreates/" + id, "PUT", debugPayload)
          ]).then(function() {
            return { count: count + 1 };
          });
        });
      }
      return Promise.all([
        restRequest("meta/latestPlane", "PUT", latestPayload),
        restGetPlaneCount(),
        restRequest("debug/planeCreates/" + id, "PUT", debugPayload)
      ]).then(function(results) {
        return { count: results[1] || 0 };
      });
    });
  }

  function createRestSocket(options) {
    var socketId = "rest_" + Date.now() + "_" + Math.random().toString(36).slice(2, 10);
    var seenMessageKeys = {};
    var seenEventKeys = {};
    var seenSideKeys = {};
    var pollTimer = null;

    function accepts(payload) {
      if (!payload) {
        return true;
      }
      if (payload.x && payload.x !== options.experience) {
        return false;
      }
      return true;
    }

    function emitValue(callback, payload, isSelf, key) {
      if (!payload || isSelf || !accepts(payload)) {
        return;
      }
      callback && callback({ d: payload.d });
      if (key) {
        return true;
      }
      return false;
    }

    function pollPath(path, seenMap, callback) {
      return restRequest(path, "GET").then(function(value) {
        value = value || {};
        var keys = Object.keys(value).sort();
        var start = Math.max(0, keys.length - 200);
        for (var i = start; i < keys.length; i++) {
          var key = keys[i];
          if (seenMap[key]) {
            continue;
          }
          seenMap[key] = 1;
          var payload = value[key];
          emitValue(callback, payload, payload && payload.senderId === socketId, key);
        }
      }).catch(function() {});
    }

    function startPolling() {
      if (pollTimer) {
        clearInterval(pollTimer);
      }
      var poll = function() {
        pollPath("live/messages", seenMessageKeys, options.onMessage);
        pollPath("live/events", seenEventKeys, options.onEvent);
        pollPath("live/side", seenSideKeys, options.onSide);
      };
      poll();
      pollTimer = setInterval(poll, 2000);
    }

    options.onReady && options.onReady();
    startPolling();

    return {
      send: function(data) {
        restRequest("live/messages", "POST", {
          d: data,
          t: options.type,
          x: options.experience,
          senderId: socketId,
          createdAt: Date.now()
        });
      },
      emitToSide: function(data) {
        restRequest("live/side", "POST", {
          d: data,
          t: options.type,
          x: options.experience,
          senderId: socketId,
          createdAt: Date.now()
        });
      },
      disconnect: function() {
        if (pollTimer) {
          clearInterval(pollTimer);
          pollTimer = null;
        }
      }
    };
  }

  function readLocalPlaneFallback() {
    try {
      if (window.Storage && Storage.get) {
        var createdPlanes = Storage.get("created_planes") || [];
        if (createdPlanes.length) {
          return createdPlanes[createdPlanes.length - 1];
        }
        var myPlanes = Storage.get("myPlanes") || [];
        if (myPlanes.length) {
          return myPlanes[0];
        }
      }
    } catch (error) {}
    return null;
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function planeRef(id) {
    return state.db ? state.db.ref("planes/" + id) : null;
  }

  function planesRef() {
    return state.db ? state.db.ref("planes") : null;
  }

  function metaRef() {
    return state.db ? state.db.ref("meta/planeCount") : null;
  }

  function latestPlaneRef() {
    return state.db ? state.db.ref("meta/latestPlane") : null;
  }

  function incrementPlaneCount() {
    var ref = metaRef();
    if (!ref) {
      return Promise.resolve(0);
    }
    return ref.transaction(function(current) {
      return (current || 0) + 1;
    }).then(function(result) {
      return result.snapshot.val() || 0;
    });
  }

  function getPlaneCount() {
    if (!init()) {
      return Promise.resolve(0);
    }
    if (state.useRest || !state.db) {
      return restGetPlaneCount();
    }
    var ref = metaRef();
    var planes = planesRef();
    if (!ref || !planes) {
      return Promise.resolve(0);
    }
    return ref.once("value").then(function(snapshot) {
      var metaCount = snapshot.val() || 0;
      return planes.once("value").then(function(planesSnapshot) {
        var value = planesSnapshot.val() || {};
        var actualCount = Object.keys(value).length;
        var count = Math.max(metaCount, actualCount);
        if (count !== metaCount) {
          ref.set(count);
        }
        return count;
      });
    });
  }

  function savePlane(data, id, isNew) {
    console.log("[PaperPlanes] Firebase bridge savePlane called", { id: id, isNew: !!isNew });
    if (!init()) {
      console.log("[PaperPlanes] Firebase bridge savePlane returning fallback count 0");
      return Promise.resolve({ count: 0 });
    }

    return ensureReady().then(function() {
      if (state.useRest || !state.db) {
        console.log("[PaperPlanes] Firebase bridge savePlane using REST");
        return restSavePlane(data, id, isNew);
      }
      console.log("[PaperPlanes] Firebase bridge savePlane using SDK");
      var payload = clone(data);
      payload.id = id;
      payload.data = JSON.stringify(payload);
      payload.updatedAt = Date.now();
      if (!payload.createdAt) {
        payload.createdAt = payload.updatedAt;
      }

      var write = planeRef(id).set(payload);
      if (isNew) {
        return write.then(function() {
          return Promise.all([
            incrementPlaneCount(),
            latestPlaneRef().set({
              id: id,
              pool: payload.pool || null,
              updatedAt: payload.updatedAt,
              createdAt: payload.createdAt
            })
          ]).then(function(results) {
            return { count: results[0] || 0 };
          });
        }).catch(function(error) {
          console.error("Firebase plane create failed", error);
          throw error;
        });
      }

      return write.then(function() {
        latestPlaneRef().set({
          id: id,
          pool: payload.pool || null,
          updatedAt: payload.updatedAt,
          createdAt: payload.createdAt
        });
        return getPlaneCount().then(function(count) {
          return { count: count };
        });
      }).catch(function(error) {
        console.error("Firebase plane update failed", error);
        throw error;
      });
    });
  }

  function getPlane(id) {
    if (!init()) {
      return Promise.resolve(null);
    }
    return ensureReady().then(function() {
      if (state.useRest || !state.db) {
        return restRequest("planes/" + id, "GET").catch(function() {
          return null;
        });
      }
      var ref = planeRef(id);
      if (!ref) {
        return null;
      }
      return ref.once("value").then(function(snapshot) {
        return snapshot.val();
      });
    });
  }

  function getLatestPlane() {
    if (!init()) {
      return Promise.resolve(null);
    }
    return ensureReady().then(function() {
      if (state.useRest || !state.db) {
        return restRequest("meta/latestPlane", "GET").then(function(latest) {
          if (!latest || !latest.id) {
            return null;
          }
          return restRequest("planes/" + latest.id, "GET").catch(function() {
            return null;
          });
        }).catch(function() {
          return null;
        });
      }
      var ref = planesRef();
      if (!ref) {
        return null;
      }
      return ref.orderByChild("updatedAt").limitToLast(1).once("value").then(function(snapshot) {
        var value = snapshot.val();
        if (!value) {
          return null;
        }
        var keys = Object.keys(value);
        return value[keys[0]];
      });
    });
  }

  function selectPlane(pool) {
    if (!init()) {
      return Promise.resolve(readLocalPlaneFallback());
    }
    function getHistoryKey() {
      return "firebase_selected_planes_" + pool;
    }
    function shuffle(values) {
      for (var i = values.length - 1; i > 0; i--) {
        var j = Math.floor(Math.random() * (i + 1));
        var temp = values[i];
        values[i] = values[j];
        values[j] = temp;
      }
      return values;
    }
    function readBag() {
      var bag = state.planeBags[pool];
      if (bag) {
        return bag.slice();
      }
      try {
        bag = JSON.parse(window.localStorage.getItem(getHistoryKey()) || "[]");
      } catch (error) {}
      if (!Array.isArray(bag)) {
        bag = [];
      }
      state.planeBags[pool] = bag;
      return bag.slice();
    }
    function writeBag(bag) {
      state.planeBags[pool] = bag.slice();
      try {
        window.localStorage.setItem(getHistoryKey(), JSON.stringify(state.planeBags[pool]));
      } catch (error) {}
    }
    function choosePlaneFromValue(value) {
      value = value || {};
      var keys = Object.keys(value).filter(function(key) {
        return !!value[key];
      });
      if (!keys.length) {
        return null;
      }
      var bag = readBag().filter(function(key) {
        return keys.indexOf(key) !== -1;
      });
      if (!bag.length) {
        bag = shuffle(keys.slice());
      }
      var selectedKey = bag.pop();
      writeBag(bag);
      return value[selectedKey];
    }
    return ensureReady().then(function() {
      if (state.useRest || !state.db) {
        return restRequest("planes", "GET").then(function(value) {
          var plane = choosePlaneFromValue(value);
          if (!plane) {
            return readLocalPlaneFallback();
          }
          return plane;
        }).catch(function() {
          return readLocalPlaneFallback();
        });
      }
      var ref = planesRef();
      if (!ref) {
        return readLocalPlaneFallback();
      }
      return ref.once("value").then(function(snapshot) {
        var value = snapshot.val();
        var plane = choosePlaneFromValue(value);
        if (plane) {
          return plane;
        }
        return readLocalPlaneFallback();
      });
    });
  }

  function connectSocket(options) {
    if (!init() || !state.db) {
      if (options && typeof options.onReady == "function") {
        setTimeout(function() {
          options.onReady();
        }, 0);
      }
      return createRestSocket(options || {});
    }
    ensureReady();

    var socketId = state.db.ref("connections").push().key;
    state.socketRef = state.db.ref("connections/" + socketId);
    var userRef = state.db.ref("users/" + socketId);
    state.socketRef.set({
      type: options.type,
      experience: options.experience,
      connectedAt: firebase.database.ServerValue.TIMESTAMP,
      hostname: window.location.hostname
    });
    userRef.set({
      socketId: socketId,
      type: options.type,
      experience: options.experience,
      hostname: window.location.hostname,
      connectedAt: firebase.database.ServerValue.TIMESTAMP,
      lastSeenAt: firebase.database.ServerValue.TIMESTAMP
    });
    state.socketRef.onDisconnect().remove();
    userRef.onDisconnect().remove();

    var messageRef = state.db.ref("live/messages");
    var eventRef = state.db.ref("live/events");
    var sideRef = state.db.ref("live/side");

    function accepts(payload) {
      if (!payload) {
        return true;
      }
      if (payload.x && payload.x !== options.experience) {
        return false;
      }
      return true;
    }

    function onMessage(snapshot) {
      var payload = snapshot.val();
      if (!accepts(payload) || (payload.senderId && payload.senderId === socketId)) {
        return;
      }
      options.onMessage && options.onMessage({ d: payload.d });
    }

    function onEvent(snapshot) {
      var payload = snapshot.val();
      if (!accepts(payload) || (payload.senderId && payload.senderId === socketId)) {
        return;
      }
      options.onEvent && options.onEvent({ d: payload.d });
    }

    function onSide(snapshot) {
      var payload = snapshot.val();
      if (!accepts(payload) || (payload.senderId && payload.senderId === socketId)) {
        return;
      }
      options.onSide && options.onSide({ d: payload.d });
    }

    messageRef.limitToLast(200).on("child_added", onMessage);
    eventRef.limitToLast(200).on("child_added", onEvent);
    sideRef.limitToLast(200).on("child_added", onSide);

    state.socketHandlers = [
      { ref: messageRef, fn: onMessage },
      { ref: eventRef, fn: onEvent },
      { ref: sideRef, fn: onSide }
    ];

    options.onReady && options.onReady();

    return {
      send: function(data) {
        userRef.update({
          lastSeenAt: firebase.database.ServerValue.TIMESTAMP
        });
        messageRef.push({
          d: data,
          t: options.type,
          x: options.experience,
          senderId: socketId,
          createdAt: firebase.database.ServerValue.TIMESTAMP
        });
      },
      emitToSide: function(data) {
        userRef.update({
          lastSeenAt: firebase.database.ServerValue.TIMESTAMP
        });
        sideRef.push({
          d: data,
          t: options.type,
          x: options.experience,
          senderId: socketId,
          createdAt: firebase.database.ServerValue.TIMESTAMP
        });
      },
      disconnect: function() {
        state.socketHandlers.forEach(function(handler) {
          handler.ref.off("child_added", handler.fn);
        });
        state.socketHandlers = [];
        if (state.socketRef) {
          state.socketRef.remove();
        }
      }
    };
  }

  window.FirebasePlanesBridge = {
    isAvailable: function() {
      return init();
    },
    connectSocket: connectSocket,
    savePlane: savePlane,
    getPlane: getPlane,
    getLatestPlane: getLatestPlane,
    getPlaneCount: getPlaneCount,
    selectPlane: selectPlane
  };
})(window);
