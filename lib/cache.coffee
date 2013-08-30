class Cache
    instance = null
    @getinstance = (cb = null, debug = false) -> instance ?= new dasCache(cb,debug)
        
    class dasCache
        memcache = {}
        idb = "dasCache"
        idbtable = "cache_objects"
        db = null
        ls = null
        debug = false
        _this = this

        """ Constructor of class dasCache 
        Preferred method of cache is indexedDB if browser supports it. 
        If not, it tries to get localstorage
        """
        constructor: (cb, dbg) ->
            debug = dbg
            console.log "initializing cache" if debug is true
            if window.indexedDB
                db = window.indexedDB
                req = db.open idb, 1
                req.onsuccess = (event) ->
                    console.log "indexedDB open successful" if debug is true
                    db = event.target.result
                    #db=null #for testing localstorage and memory cache
                    #ls = window.localStorage || null #for testing localstorage
                    cb() if typeof cb is "function"
                req.onerror = () ->
                    ls = if window.localStorage? then window.localStorage else null
                    cb() if typeof cb is "function"
                req.onupgradeneeded = (event) ->
                    event?.target?.result?.createObjectStore idbtable, {keyPath: "key" }
            else
                ls = if window.localStorage? then window.localStorage else null
                cb() if typeof cb is "function"

                    
        """ Sets a value in cache 
            @param key (String)
            @param value (Any)
            @param ttl (Number)
            @param cb (Function)
        """                    
        set: (key,value,ttl=0,cb)->
            console.log "setting in memory" if debug is true
            key += ''
            ttl = if isNaN(ttl) is false then parseInt(ttl) else 0
            memcache[idb + "_" + key] = {"value": value,"ttl": ttl,"date": +new Date()}
            if db?
                console.log "setting in indexed db " if debug is true
                try
                    ls = db.transaction([idbtable],"readwrite").objectStore(idbtable)
                    r = ls?.put {"key":key,"value":value,"ttl":ttl,"date": +new Date()}
                    r.onsuccess = r.onerror = () ->
                        cb() if typeof cb is "function"
                        return
                    
                catch error
                    console.log error if debug is true
                    
             else if ls?.setItem
                console.log "setting in localstorage" if debug is true
                ls.setItem idb + "_" + key, JSON.stringify({"value": value,"ttl": ttl,"date": +new Date()})
                cb() if typeof cb is "function"
                return       
            
            cb() if typeof cb is "function"
            return

        """ Private method to set value in memory when retrieving from indexedDB
            @param key (String)
            @param value (Any)
            @param ttl (Number)
            @param cb (Function)
        """        
        _setOnlyMemory = (k,v,date,ttl=0) ->
            console.log "setting in memory" if debug is true
            memcache[idb + "_" + k] = {"value": v,"ttl": ttl,"date": date}
            
        """ Private method to check if cache key is outdated
            @param date (Date in millis)
            @param ttl (Number in millis)
            @return boolean
        """        
        _isOutDated = (date, ttl=0) ->
            if ttl isnt 0 then (date + ttl) < +new Date() else false
            
        """ Get a cache key
            @param key (String)
            @param cb (Function) it passes the value of the key as param
        """     
        get: (key, cb)->
            key += '' 
            if memcache[idb + "_" + key]
                console.log "get from memory" if debug is true
                if _isOutDated(memcache[idb + "_" + key].date, memcache[idb + "_" + key].ttl) is false  
                    cb memcache[idb + "_" + key].value 
                else
                    this.del key
                    cb null
                    
            else if db?
                console.log "get from indexed db" if debug is true
                if typeof cb is "function"
                    ls = db.transaction([idbtable],"readonly").objectStore(idbtable)
                    r = ls.get(key) 
                    r.onsuccess = (ev) => 
                        if ev?.target?.result?.value
                            v = ev.target.result
                            if _isOutDated(v.date,v.ttl) is false
                                _setOnlyMemory key, v.value, v.date, v.ttl 
                                cb v.value
                            else
                                this.del key    
                            return
                        cb null
                    r.onerror = () ->
                        cb null
                        
            else if ls?.getItem
                console.log "get from localstorage" if debug is true
                v = JSON.parse ls?.getItem  idb+"_"+key
                if v?
                    if _isOutDated(v?.date,v?.ttl) is false
                        memcache[idb + "_" + key] ?={"value": v.value,"date": v.date,"ttl" : v.ttl} 
                        cb memcache[idb + "_" + key].value
                    else
                        this.del key
                    return
                cb null
             
        """ Removes a cache key
            @param key (String)
        """     
        del: (key)->
            key += ''
            console.log "removing from memory" if debug is true
            delete memcache[idb + "_" + key]
            if db?
               console.log "removing from indexedDB" if debug is true
               db.transaction([idbtable],"readwrite").objectStore(idbtable).delete key
            else if ls?.removeItem 
                console.log "removing from localstorage" if debug is true
                ls?.removeItem idb + "_" + key
             
        """ Clear cache
        """
        clear: () ->
            console.log "deleting all" if debug is true

            memcache = {}
            if db?
                ls = db.transaction([idbtable],"readwrite").objectStore(idbtable)
                ls.clear()
            if ls?.setItem
                ls.removeItem k for k of ls when k.indexOf idb is 0 

        """ Get all keys
            @param cb (Function) it passes an Array of keys
        """     
        getAllKeys: (cb) ->
            console.log "getting all keys" if debug is true
            items = [];
            for k of memcache
                if _isOutDated(memcache[k].date,memcache[k].ttl) is false
                    items.push k.replace(idb+"_","")
                else
                    this.del k.replace(idb+"_","")

            if items.length > 0
                console.log "getting all keys from memory" if debug is true
                cb(items) if typeof cb is "function"
                return
            
            if db?
                console.log "getting all keys from db" if debug is true
                trans = db.transaction([idbtable],"readwrite");
                ls = trans.objectStore(idbtable);
                               
                trans.oncomplete = (event) ->
                    cb(items) if typeof cb is "function"
                                    
                cursorRequest = ls.openCursor()
                                    
                cursorRequest.onerror = (error) -> 
                    console.log error
                                    
                cursorRequest.onsuccess = (event) =>                    
                    cursor = event.target.result
                    if cursor
                            if _isOutDated(cursor.value.date,cursor.value.ttl) is false
                                items.push cursor.key
                            else 
                                this.del cursor?.key
                        cursor?.continue();
                        
                return
            
            if ls?.setItem
                console.log "getting all keys from localstorage" if debug is true
                for k of ls
                    v = JSON.parse ls?.getItem k
                    k = k.replace(idb+"_","") 
                    if _isOutDated(v.date,v.ttl) is false
                        items.push k
                    else
                        this.del k
                cb(items) if typeof cb is "function"