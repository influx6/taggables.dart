part of taggables;


class TagNS{
	final MapDecorator blueprints = MapDecorator.create();
	String id;

	static create(n) => new TagNS(n);

	TagNS(String d){
          this.id = d.toLowerCase();
	}

	Tag createTag(html.Element tag,[String bypass]){
          var tagName = Valids.exist(bypass) ? bypass : tag.tagName.toLowerCase();
          if(!this.blueprints.has(tagName)) return null;
          var blueprint = this.blueprints.get(tagName);
          var f = Tag.create(tag,this.id);
          blueprint(f);
          return f;
	}

	void register(String tag,Function n(Tag g)){
		this.blueprints.add(tag.toLowerCase(),n);
	}

	void unregister(String tag){
            tag = tag.toLowerCase();
            this.blueprints.destroy(tag);
	}

	void destroy(){
		this.blueprints.clear();
	}

	bool has(String nm) => this.blueprints.has(nm.toLowerCase());

	String toString() => this.blueprints.toString();

	List get tags => this.blueprints.core.keys.toList();

        List toList(){
          return this.blueprints.core.keys.toList();
        }

        int totalBlueprints(){
          return this.blueprints.core.length;
        }
}

class TagRegistry{
	MapDecorator namespace;
	MapDecorator _providerCache;
        Set _cacheList;
        int _totalTags;

	static create() => new TagRegistry();

	TagRegistry(){
            this.namespace = MapDecorator.create();
            this._providerCache = MapDecorator.create();
            this._cacheList = new Set<String>();
            this._totalTags = 0;
	}
        
        void _updateCache([String r]){
            var count = 0;
            Enums.eachAsync(this.namespace.core,(e,i,o,fn){
               count += e.totalBlueprints();
               this._cacheList.addAll(e.toList());
               return fn(null);
            },(_,err){
              this._totalTags = count;
              if(Valids.exist(r)) this._cacheList.remove(r);
            });
        }
        
        int get size => this._totalTags;
        List get tags => this._cacheList.toList();
        Set get cache => this._cacheList;
  
        bool providesTag(String n) => this._cacheList.contains(n.toLowerCase());

	void addNS(String ns) => this.namespace.add(ns.toLowerCase(),TagNS.create(ns));
	void removeNS(String ns) => this.namespace.destroy(ns.toLowerCase()).destroy();
	TagNS ns(String n) => this.namespace.get(n.toLowerCase());

	void register(String s,String tag,Function n){
		if(!this.namespace.has(s.toLowerCase())) this.addNS(s);
		var nsg = this.ns(s);
		if(Valids.notExist(nsg)) return null;
		QueryUtil.defaultValidator.addTag(tag);
		nsg.register(tag,n);
                this._updateCache();
	}

	void unregister(String n,String tag){
                var nsg = this.ns(n);
		if(Valids.notExist(nsg)) return null;
		nsg.unregister(tag);
                this._updateCache(tag);
	}

	dynamic createTag(String s,String tagName,[html.Element e]){
		var nsg = this.ns(s);
		if(Valids.notExist(nsg)) return null;
		return nsg.createTag(tagName,this,e);
	}

	bool hasNS(String ns) => this.namespace.has(ns.toLowerCase());

	bool hasTag(String nsg,String tagName){
		if(this.hasNS(nsg)) return false;
		return this.ns(nsg).has(tagName);
	}

        Future<TagNS> delegateSearch(String tagName,[String tns]){
          var comp = new Completer();
          if(Valids.exist(tns)){
            if(!this.hasNS(tns)) comp.completeError(new Exception('$tns for $tagName NOT FOUND!'));
            else comp.complete(this.ns(tns));
          }
          this.findProvider(tagName,comp.complete,(f){
            return comp.completeError(new Exception('Provider for $tagName NOT FOUND!'));
          });
          return comp.future;
        }

	TagNS findProvider(String tagName,[Function n,Function m]){
                tagName = tagName.toLowerCase();
                if(this._providerCache.has(tagName)) return n(this._providerCache.get(tagName));
		Enums.eachAsync(this.namespace.storage,(e,i,o,fn){
			if(e.has(tagName)){
				if(Valids.exist(n)) n(e);
                                this._providerCache.add(tagName,e);
				return fn(true);
			}
			return fn(null);
		},(_,err){
			if(Valids.notExist(err) && Valids.exist(m)) m(tagName);
		});

		return this._providerCache.get(tagName);
	}

	String toString() => this.namespace.toString();

        void destroy(){
            this.namespace.clear();
            this._providerCache.clear();
            this._cacheList.clear();
            this._totalTags = 0;
        }
}

class DistributedObserver{
	final consumers = Hub.createDistributor('distributed-consumers');
	final mutationSet = new List();
	Function mutatorFn;

	static create([n]) => new DistributedObserver.ensure(n);

	factory DistributedObserver.ensure([Function n]){
		if(!!html.MutationObserver.supported) 
			return DistributedMutation.create(n);
		return DistributedHooks.create(n);
	}

	DistributedObserver([Function n]){
          this.mutatorFn = Funcs.switchUnless(n,Funcs.identity);
	}

	void handleMutation(e){
          this.mutationSet.add(e);
	}

	void observe(html.Element e,[Map a]);
	void disconnect();

	void bind(Function n) => this.consumers.on(n);
	void bindOnce(Function n) => this.consumers.once(n);
	void unbind(Function n) => this.consumers.off(n);
	void unbindOnce(Function n) => this.consumers.offOnce(n);
	void bindWhenDone(Function n) => this.consumers.whenDone(n);
	void unbindWhenDone(Function n) => this.consumers.offWhenDone(n);

	void destroy(){
          this.consumers.free();
          this.mutationSet.clear();
          this.mutatorFn = null;
	}

}

class MutationEventDecorator{
	html.Event e;
	MapDecorator props;

	static create(e) => new MutationEventDecorator(e);

	MutationEventDecorator(this.e){
		this.props = MapDecorator.create();
                
		var type = this.e.type.replaceAll('DOM','').toLowerCase(), an = [], rn = [];

		if(Valids.match(type,'attrmodified')){
			this.props.update('type','attributes'); 
		}

		if(Valids.match(type,'elementnamechanged')){
			this.props.update('type','attributes'); 
		}

		if(Valids.match(type,'noderemoved') || Valids.match(type,"noderemovedfromdocument") || Valids.match(type,'nodeinsertedintodocument') || Valids.match(type,'nodeinserted')){
			this.props.update('type','childList');
			if(Valids.match(type,'nodeinserted') || Valids.match(type,"nodeinsertedintodocument")) an.add(this.e.target);
			if(Valids.match(type,'noderemoved') || Valids.match(type,"noderemovedfromdocument")) rn.add(this.e.target);
		}

		var triggerCheck = (Sring n,Function r,Function m){
			try{
				this.props.update(n,r());
			}catch(e){
				this.props.update(n,m());
			};
		};

		var fnull = Funcs.always(null);

		this.props.update('addedNodes',an);
		this.props.update('removedNodes',rn);

		triggerCheck('attributeName',() => this.e.attrName,fnull);
		triggerCheck('attributeOldValue',() => this.e.prevValue,fnull);
		triggerCheck('target',() => this.e.relatedNode,() => this.e.currentTarget);
		triggerCheck('nextSibling',() => this.e.target.nextElementSibling,fnull);
		triggerCheck('previousSibling',() => this.e.target.previousElementSibling,fnull);
		triggerCheck('characterData',() => this.e.target.clipboardData,fnull);
		triggerCheck('characterDataOldValue',() => this.e.target.clipboardData,fnull);

	}

	List get addedNodes => this.props.get('addedNodes');
	List get removedNodes => this.props.get('removedNodes');

	dynamic get target => this.props.get('target');

	dynamic get nextSibling => this.props.get('nextSibling');

	dynamic get previousSibling => this.props.get('previousSibling');

	String get type => this.props.get('type');

	String get attributeName => this.props.get('attributeName');
	String get characterData => this.props.get('characterData');

	String get attributeNamespace => this.props.get('attributeNamespace');

	String get attributeOldValue => this.props.get('attributeOldValue');
	String get characterDataOldValue => this.props.get('characterDataOldValue');

	void destroy(){
		this.props.free();
	}
}

class DistributedHooks extends DistributedObserver{
	final observer = ElementBindings.create();

	static create([n]) => new DistributedHooks(n);

	DistributedHooks([Function n,bool noMutation]): super(n);

	void connectMutationEvents(){
          this.bindMutation('DOMNodeInserted');
          this.bindMutation('DOMNodeRemoved');
          this.bindMutation('DOMAttrModified');
          /*this.bindMutation('DOMSubtreeModified');*/
	}

	void bindMutation(String name){
		this.observer.addHook(name,this.handleMutation);
	}

	void handleMutation(e){
		var m = this.mutatorFn(MutationEventDecorator.create(e));
		this.consumers.emit(m);
		super.handleMutation(m);
	}

	void observe(html.Element e,[Map a]){
		this.observer.bindTo(e);
		if(a != null) a.clear();
	}

	void disconnect(){
		this.observer.unHookAll();
	}

	void destroy(){
		this.observer.destroy();
	}

	bool get isMutationObserver => false;

	String toString() => this.observer;

}

class DistributedMutation extends DistributedObserver{
	html.MutationObserver observer;

	static create([n]) => new DistributedMutation(n);

	DistributedMutation([n]): super(n){
		this.observer = new html.MutationObserver(this.handleMutation);
	}

	void handleMutation(List a,dynamic handle){
		a.forEach((k){
			var m = this.mutatorFn(k);
			super.handleMutation(m);
			this.consumers.emit(m);
		});
	}

	void observe(html.Element e,[Map a]){
		a = Funcs.switchUnless(a,{});
		Function.apply(this.observer.observe,[e],Hub.encryptNamedArguments(a));
	}

	void disconnect(){
		this.observer.disconnect();
	}

	void destroy(){
          this.disconnect();
	}

	bool get isMutationObserver => true;

	String toString() => this.observer;
}

class DistributedManager{
        final Map _defaults = {
          'attributes':true,
          'attributeOldValue': true,
          'subtree': true,
          'childList': true,
          'characterData':true,
          'characterDataOldValue':true
        };
	DistributedObserver observer;
	html.Element element;
	ElementBindings hooks;

	static create(n) => new DistributedManager(n);

	DistributedManager(this.observer){
            this.hooks = ElementBindings.create();
            this.hooks.addHook('attributeChange');
            this.hooks.addHook('attributeRemoved');
            this.hooks.addHook('childAdded');
            this.hooks.addHook('childRemoved');

            this.observer.bind((n){

              var m = n;
              if(n is html.CustomEvent) m = n.detail;

              var type = m.type.toLowerCase();
              Funcs.when(Valids.match(type,'attributes'),(){
                if(Valids.exist(m.attributeName)){
                        this.hooks.fireHook(this.hasAttribute(m.attributeName) 
                                ? 'attributeChange' : 'attributeRemoved',n);
                }
                if(Valids.exist(m.attributeNamespace)){
                        this.hooks.fireHook(this.hasAttributeNS(m.attributeNamespace) 
                                ? 'attributeChange' : 'attributeRemoved',n);
                }
              });

              Funcs.when(Valids.match(type,'childlist'),(){
                if(m.addedNodes.length > 0) return this.hooks.fireHook('childAdded',n);
                if(m.removedNodes.length > 0) return this.hooks.fireHook('childRemoved',n);
              });

            });

            if(!this.observer.isMutationObserver) 
                this.observer.connectMutationEvents();
	}

	bool hasAttribute(String n){
          if(Valids.notExist(this.element)) return false;
          return this.element.attributes.containsKey(n);
	}

	bool hasAttributeNS(String ns){
          return this.hasAttribute(ns);
	}

	void observe(html.Element e,[Map a]){
		a = Funcs.switchUnless(a,this._defaults);

		this.element = e;
		this.hooks.bindTo(e);
		this.observer.observe(e,a);
	}

	void disconnect(){
		this.hooks.unHookAll();
		this.observer.disconnect();
	}

	void destroy(){
		this.disconnect();
		this.hooks.destroy();
		this.observer.destroy();
		this.element = null;
	}

	void bindHook(String nm,Function n) => this.hooks.bind(nm,n);
	void bindHookOnce(String nm,Function n) => this.hooks.bindOnce(nm,n);
	void unbindHook(String nm,Function n) => this.hooks.unbind(nm,n);
	void unbindHookOnce(String nm,Function n) => this.hooks.unbindOnce(nm,n);
	void bindWhenDone(String nm,Function n) => this.hooks.bindWhenDone(nm,n);
	void unbindWhenDone(String nm,Function n) => this.hooks.unbindWhenDone(nm,n);


	void bindMutation(Function n) => this.observer.bind(n);
	void bindMutationOnce(Function n) => this.observer.bindOnce(n);
	void unbindMutation(Function n) => this.observer.unbind(n);
	void unbindMutationOnce(Function n) => this.observer.unbindOnce(n);
	void bindMutationWhenDone(Function n) => this.observer.bindWhenDone(n);
	void unbindMutationWhenDone(Function n) => this.observer.unbindWhenDone(n);

	void addHook(String name,[n]) => this.hooks.addHook(name,n);
	void fireHook(String name,n) => this.hooks.fireHook(name,n);
	void removeHook(String name) => this.hooks.removeHook(name);
	dynamic getHook(String name) => this.hooks.getHooks(name);

}

class DualObservers extends EventContract{
  ElementObservers rootObserver;
  ElementObservers parentObserver;

  DualObservers([DistributedObserver childob,DistributedObserver parentob]){

    childob = Funcs.switchUnless(childob,DistributedObserver.create());
    parentob = Funcs.switchUnless(parentob,DistributedObserver.create());

    this.rootObserver = ElementObservers.create(childob);
    this.parentObserver = ElementObservers.create(parentob);

    this.parentObserver.bind('childAdded',(n){
      if(Enums.filterItem(n.detail.addedNodes,this.observer.element).length > 0)
        return this.observer.fireEvent('domAdded',n);
    });

    this.parentObserver.bind('childRemoved',(n){
      if(Enums.filterItem(n.detail.removedNodes,this.observer.element).length > 0)
        return this.observer.fireEvent('domRemoved',n);
    });
  }

  void observeRoot(Map a,[Function n]){
    this.rootObserver.observe(this.root,a,n);
  }

  void observeParent(html.Element p,Map a,[Function n]){
    this.parentObserver.observe(p,a,n);
    if(Valids.exist(n)) return n(this.root,p);
    if(this.root.parent == p) return null;
    return p.append(this.root);
  }

  ElementObservers get observer => this.rootObserver;

  void bind(String name,Function n) => this.observer.bind(name,n);
  void bindOnce(String name,Function n) => this.observer.bindOnce(name,n);
  void unbind(String name,Function n) => this.observer.unbind(name,n);
  void unbindOnce(String name,Function n) => this.observer.unbindOnce(name,n);
  void bindWhenDone(String nm,Function n) => this.observer.bindWhenDone(nm,n);
  void unbindWhenDone(String nm,Function n) => this.observer.unbindWhenDone(nm,n);

  Function get addEvent => this.observer.addEvent;
  Function get removeEvent => this.observer.removeEvent;
  Function get fireEvent => this.observer.fireEvent;
  Function get events => this.observer.getEvent;

}

class ElementObservers extends EventContract{
	DistributedObserver dobs;
	DistributedManager observer;
	html.Element element;

	static create(e) => new ElementObservers(e);

	ElementObservers(this.dobs){
          this.observer = DistributedManager.create(this.dobs);
          this.observer.addHook('domReady');
          this.observer.addHook('domAdded');
          this.observer.addHook('domRemoved');
	}

	void destroy(){
		this.dobs.destroy();
		this.observer.destroy();
		this.element = null;
	}

	void addEvent(String n,[Function m]){
		this.observer.addHook(n,m);
                this.bind(n,Funcs.emptySingleFunction);
	}

	void removeEvent(String n){
            this.observer.removeHook(n);
	}

	void fireEvent(String n,dynamic a){
            this.observer.fireHook(n,a);
	}

	dynamic getEvent(String n) => this.observer.getHook(n);

        void observe(html.Element e,Map elemOptions,[Function insert]){
          this.element = e;
          this.observer.observe(this.element,elemOptions);
	}

	void bind(String name,Function n) => this.observer.bindHook(name,n);
	void bindOnce(String name,Function n) => this.observer.bindHookOnce(name,n);
	void unbind(String name,Function n) => this.observer.unbindHook(name,n);
	void unbindOnce(String name,Function n) => this.observer.unbindHookOnce(name,n);
	void bindWhenDone(String nm,Function n) => this.observer.bindWhenDone(nm,n);
	void unbindWhenDone(String nm,Function n) => this.observer.unbindWhenDone(nm,n);

}

