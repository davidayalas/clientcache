Client Cache in CoffeeScript
==============================================

Experiment on client cache singleton coded in CoffeeScript. It's fully functional (get, set, remove, expiration time, ...). It stores data in memory and in HTML5 indexedDB or localStorage, if they are available.

How to use
-----------

cache = Cache.getinstance callback [, debug as boolean]

Methods
--------

*	cache.**set** key, value[, ttl in milliseconds][, callback] 

*	cache.**get** key, callback

	callback gets the value as argument<br />

*	cache.**del** key <br />

*	cache.**clear**

*	cache.**getAllKeys** callback
	
	callback gets an Array as argument

Sample
-------

	cache = Cache.getinstance () ->
	    cache.get "lastvisit", (value) ->
	        if value?
	            console.log new Date(value)
	            #...
	            
	        cache.set "lastvisit", +new Date() #user last visit

Try it
-------

http://jsfiddle.net/davixyz/gZ97p/