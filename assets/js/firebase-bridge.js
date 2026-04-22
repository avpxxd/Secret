(function(window) {
  var state = {
    initialized: false,
    db: null,
    socketRef: null,
    socketHandlers: [],
    liveHandlers: [],
    authReady: null
  };

  function hasConfig() {
    var config = window.FIREBASE_CONFIG || {};
    return !!(config.apiKey && config.authDomain && config.databaseURL && config.projectId && config.appId && config.apiKey.indexOf("YOUR_") !== 0);
  }

  function init() {
    if (state.initialized) {
      return true;
    }
    if (!hasConfig()) {
      return false;
    }
    if (!window.firebase) {
      return false;
    }
    if (!firebase.apps.length) {
      firebase.initializeApp(window.FIREBASE_CONFIG);
    }
    state.db = firebase.database();
    if (firebase.auth) {
      state.authReady = firebase.auth().signInAnonymously().then(function() {
        return true;
      }).catch(function(error) {
        console.warn("Firebase anonymous auth unavailable", error && error.message ? error.message : error);
        return true;
      });
    } else {
      state.authReady = Promise.resolve(true);
    }
    state.initialized = true;
    window.FirebasePlanesBridgeReady = true;
    return true;
  }

  function ensureReady() {
    init();
    return state.authReady || Promise.resolve(true);
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
    if (!init() || !state.db) {
      return Promise.resolve(0);
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
    if (!init()) {
      return Promise.resolve({ count: 0 });
    }

    return ensureReady().then(function() {
      if (!state.db) {
        return { count: 0 };
      }
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
    return ensureReady().then(function() {
      var ref = planesRef();
      if (!ref) {
        return readLocalPlaneFallback();
      }
      return ref.orderByChild("pool").equalTo(pool).once("value").then(function(snapshot) {
        var value = snapshot.val();
        if (!value) {
          return ref.orderByChild("updatedAt").limitToLast(1).once("value").then(function(fallbackSnapshot) {
            var fallbackValue = fallbackSnapshot.val();
            if (fallbackValue) {
              var fallbackKeys = Object.keys(fallbackValue);
              return fallbackValue[fallbackKeys[0]];
            }
            return readLocalPlaneFallback();
          });
        }
        var keys = Object.keys(value);
        return value[keys[Math.floor(Math.random() * keys.length)]];
      });
    });
  }

  function connectSocket(options) {
    if (!init()) {
      if (options && typeof options.onReady == "function") {
        setTimeout(function() {
          options.onReady();
        }, 0);
      }
      return {
        send: function() {},
        emitToSide: function() {},
        disconnect: function() {}
      };
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
