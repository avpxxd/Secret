(function(window) {
  var state = {
    initialized: false,
    db: null,
    socketRef: null,
    socketHandlers: [],
    liveHandlers: []
  };

  function hasConfig() {
    var config = window.FIREBASE_CONFIG || {};
    return !!(window.firebase && firebase.apps && config.apiKey && config.authDomain && config.databaseURL && config.projectId && config.appId && config.apiKey.indexOf("YOUR_") !== 0);
  }

  function init() {
    if (state.initialized) {
      return true;
    }
    if (!hasConfig()) {
      return false;
    }
    if (!firebase.apps.length) {
      firebase.initializeApp(window.FIREBASE_CONFIG);
    }
    state.db = firebase.database();
    state.initialized = true;
    return true;
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function planeRef(id) {
    return state.db.ref("planes/" + id);
  }

  function planesRef() {
    return state.db.ref("planes");
  }

  function metaRef() {
    return state.db.ref("meta/planeCount");
  }

  function incrementPlaneCount() {
    return metaRef().transaction(function(current) {
      return (current || 0) + 1;
    }).then(function(result) {
      return result.snapshot.val() || 0;
    });
  }

  function getPlaneCount() {
    return metaRef().once("value").then(function(snapshot) {
      var metaCount = snapshot.val() || 0;
      return planesRef().once("value").then(function(planesSnapshot) {
        var value = planesSnapshot.val() || {};
        var actualCount = Object.keys(value).length;
        var count = Math.max(metaCount, actualCount);
        if (count !== metaCount) {
          metaRef().set(count);
        }
        return count;
      });
    });
  }

  function savePlane(data, id, isNew) {
    if (!init()) {
      return Promise.reject(new Error("Firebase is not configured"));
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
        return getPlaneCount().then(function(count) {
          return { count: count };
        });
      });
    }

    return write.then(function() {
      return getPlaneCount().then(function(count) {
        return { count: count };
      });
    });
  }

  function getPlane(id) {
    if (!init()) {
      return Promise.reject(new Error("Firebase is not configured"));
    }
    return planeRef(id).once("value").then(function(snapshot) {
      return snapshot.val();
    });
  }

  function getLatestPlane() {
    if (!init()) {
      return Promise.reject(new Error("Firebase is not configured"));
    }
    return planesRef().orderByChild("updatedAt").limitToLast(1).once("value").then(function(snapshot) {
      var value = snapshot.val();
      if (!value) {
        return null;
      }
      var keys = Object.keys(value);
      return value[keys[0]];
    });
  }

  function selectPlane(pool) {
    if (!init()) {
      return Promise.reject(new Error("Firebase is not configured"));
    }
    return planesRef().orderByChild("pool").equalTo(pool).once("value").then(function(snapshot) {
      var value = snapshot.val();
      if (!value) {
        return planesRef().orderByChild("updatedAt").limitToLast(1).once("value").then(function(fallbackSnapshot) {
          var fallbackValue = fallbackSnapshot.val();
          if (!fallbackValue) {
            return null;
          }
          var fallbackKeys = Object.keys(fallbackValue);
          return fallbackValue[fallbackKeys[0]];
        });
      }
      var keys = Object.keys(value);
      return value[keys[Math.floor(Math.random() * keys.length)]];
    });
  }

  function connectSocket(options) {
    if (!init()) {
      return null;
    }

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
