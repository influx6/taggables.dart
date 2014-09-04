part of taggables;

class QueryShell{
    html.Element root;
    QueryShell _ps;
    
    static create(d) => new QueryShell(d);
    QueryShell(this.root);

    html.Element get parent => this.root.parentNode;

    QueryShell get p{
      if(Valids.exist(this._ps)) return this._ps;
      if(Valids.notExist(this.parent)) return null;
      this._ps = QueryShell.create(this.parent);
      return this._ps;
    }

    dynamic css(dynamic a){
      if(Valids.isList(a)) return TagUtil.getCSS(this.root,a);
      if(Valids.isMap(a)) return TagUtil.cssElem(this.root,a);
      return null;
    }
    
    bool matchAttr(String n,dyanmic v){
      if(!this.hasAttr(n)) return false;
      return Valids.match(this.attr(n),v);
    }

    bool matchData(String n,dyanmic v){
      if(!this.hasData(n)) return false;
      return Valids.match(this.data(n),v);
    }

    bool hasAttr(String n) => this.root.attributes.containsKey(n);
    bool hasData(String n) => this.root.dataset.containsKey(n);
    
    dynamic attr(String n,[dynamic val,Function fn]){
      var dv = this.root.getAttribute(n);
      if(Valids.exist(fn)) fn(dv);
      if(Valids.notExist(val)) return dv;
      return this.root.attributes[n] = val;
    }

    dynamic data(String n,[dynamic val,Function fn]){
      var dv = this.root.dataset[n];
      if(Valids.exist(fn)) fn(dv);
      if(Valids.notExist(val)) return dv;
      return this.root.dataset[n] = val;
    }

    dynamic query(n,[v]) => TagUtil.queryElem(this.root,n,v);
    dynamic queryAll(n,[v]) => TagUtil.queryAllElem(this.root,n,v);

    dynamic get style => this.root.getComputedStyle();

    dynamic createElement(String n,[String content]){
        var elem = TagUtil.createElement(n);
        if(Valids.exist(content)) elem.setInnerHtml(content);
        TagUtil.defaultValidator.addTag(elem.tagName);
        this.root.append(elem);
        return elem;
    }

    dynamic createHtml(String markup){
        var elem = TagUtil.createHtml(markup);
        TagUtil.defaultValidator.addTag(elem.tagName);
        this.root.append(elem);
        return elem;
    }

    dynamic toHtml() => TagUtil.liquify(this.root);
    void useHtml(html.Element l) => TagUtil.deliquify(l,this.root);

    void dispatchEvent(String d,[v]) => TagUtil.dispatch(this.root,d,v);

    void queryMessage(String sel,String type,d) => this.deliverMessage(sel,type,d,this.root);
    void queryMassMessage(String sel,String type,d) => this.deliverMassMessage(sel,type,d,this.root);

}

class DisplayHook{
	TaskQueue tasks;
	html.Window w;
	Switch alive;
	List<Timers> _repeaters;
	int _frameid;

	static create(w) => new DisplayHook(w);

	DisplayHook(this.w){
          this._repeaters = new List<Timers>();
          this.tasks = TaskQueue.create(false);
          this.alive = Switch.create();
          this.tasks.immediate(this._scheduleDistributors);
          this.alive.switchOn();
	}

	int get id => this._frameid;
	
	void schedule(Function m(int ms)) => this.tasks.queue(m);
	void scheduleDelay(int msq,Function m(int ms)) => this.tasks.queueAfter(msq,m);
	void scheduleImmediate(Function m(int ms)) => this.tasks.immediate(m);
	Timer scheduleEvery(int msq,Function m){
		var t = this.tasks.queueEvery(msq,m);
		this._repeaters.add(t);
		return t;
	}

	void _scheduleDistributors([n]){
		this.tasks.queue(this._scheduleDistributors);
	}

	void emit([int n]){
		this.tasks.exec(n);
		this.run();
	}

	void run(){
		if(!this.alive.on()) this.alive.switchOn();
		this._frameid = this.w.requestAnimationFrame((i) => this.emit(i));
	}

	void stop(){
		this.alive.switchOff();
		this.w.cancelAnimationFrame(this._frameid);
		this._repeaters.forEach((f) => f.cancel());
		this.tasks.clearJobs();
	}

	String toString() => "DisplayHook with ${this._frameid}";

        void destroy(){
          this.repeaters.clear();
          this.tasks.destroy();
          this.alive.close();
          this.w = null;
        }

}

class CustomValidator{
	html.NodeValidatorBuilder _validator;

	CustomValidator(){
		this._validator = new html.NodeValidatorBuilder();
		this.rules.allowSvg();
		this.rules.allowHtml5();
		this.rules.allowInlineStyles();
		this.rules.allowTextElements();
		this.rules.allowTemplating();
		this.rules.allowElement('script',attributes:['id','data','rel']);
		this.rules.allowElement('link',attributes:['id','data','rel']);
		this.rules.allowElement('script',attributes:['id','data','rel']);
	}

	void addTag(String n){
		this.rules.allowElement(n.toLowerCase());
	}

	dynamic get rules => this._validator;
}

abstract class EventHandler{
	void bind(String name,Function n);
	void bindOnce(String name,Function n);
	void unbind(String name,Function n);
	void unbindOnce(String name,Function n);
}

class ElementHooks{
	final hooks = MapDecorator.create();
	final List<html.Element> _hiddenElements;
	bool _supportHiddenElement = false;
	html.Element element;

	static create() => new ElementHooks();

	ElementHooks();

	void enableMutipleElements() => this._supportHiddenElement = true;
	void disabeMultipleElements() => this._supportHiddenElement = false;
	bool get supportHidden => !!this._supportHiddenElement;

	void destroy(){
		this.unHookAll();
		this.hooks.onAll((n,k) => k.free());
		this.hooks.clear();
		this.element = null;
	}

	void _bindHidden(html.Element e){
		if(this._hiddenElements.contains(e)) return null;
		this._hiddenElements.add(e);
		this.hooks.onAll((k,v){
			this.addHook(k,null,e);
		});
	}

	void _unbindAllHidden(){
		this._hiddenElements.forEach((f){
			this.hooks.onAll((k,v){
				this.removeHook(k,f);
			});
		});
	}

	void _rebindAllHidden(){
		this._hiddenElements.forEach((f){
			this.hooks.onAll((k,v){
				this.addHook(k,null,f);
			});
		});
	}

	void bindTo(html.Element e){
		if(this.supportHidden) return this._bindHidden(e);
		this.unHookAll();
		this.element = e;
		this.rebindAll();
	}

	void rebindAll(){
		if(this.supportHidden) return this._rebindAllHidden();
		this.hooks.onAll((k,v){
			this.addHook(k);
		});
	}

	void unHookAll(){
		if(this.supportHidden) return this._unbindAllHidden();
		this.hooks.onAll((k,v){
			this.removeHook(k);
		});
	}

	dynamic getHooks(String name) => this.hooks.get(name);

	void addHook(String name,[Function n,html.Element hidden]){
		var ds, elem = Valids.exist(hidden) ? hidden : this.element;
		if(this.hooks.has(name)){
			ds = this.getHooks(name);
		}else{
			ds = Hub.createDistributor('$name-hook');
			this.hooks.add(name,ds);
		}

		if(Valids.exist(n)) ds.on(n);
		if(Valids.exist(elem)) 
			elem.addEventListener(name,ds.emit,false);
	}

	void removeHook(String name,[html.Element e]){
		if(!this.hooks.has(name)) return null;

		var ds = this.hooks.get(name), elem = Valids.exist(e) ? e : this.element;

		if(Valids.exist(elem)) 
			elem.removeEventListener(name,ds.emit,false);
	}

	void fireHook(String name,dynamic n){
		if(!this.hooks.has(name)) return null;

		var e = (n is html.CustomEvent ? (n.eventPhase < 2 ? n : 
			new html.CustomEvent(name,detail: n.detail)) 
			: new html.CustomEvent(name,detail: n));

		if(Valids.notExist(this.element)) return this.hooks.get(name).emit(e);
		return this.element.dispatchEvent(e);
	}

	void bind(String name,Function n){
		if(!this.hooks.has(name)) return null;
		return this.hooks.get(name).on(n);
	}

	void bindWhenDone(String name,Function n){
		if(!this.hooks.has(name)) return null;
		return this.hooks.get(name).whenDone(n);
	}

	void unbindWhenDone(String name,Function n){
		if(!this.hooks.has(name)) return null;
		return this.hooks.get(name).offWhenDone(n);
	}

	void bindOnce(String name,Function n){
		if(!this.hooks.has(name)) return null;
		return this.hooks.get(name).once(n);
	}

	void unbind(String name,Function n){
		if(!this.hooks.has(name)) return null;
		return this.hooks.get(name).off(n);
	}

	void unbindOnce(String name,Function n){
		if(!this.hooks.has(name)) return null;
		return this.hooks.get(name).offOnce(n);
	}

	String toString() => this.hooks.toString();
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
	final observer = ElementHooks.create();

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
		this.observer.destroy();
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
	ElementHooks hooks;

	static create(n) => new DistributedManager(n);

	DistributedManager(this.observer){
            this.hooks = ElementHooks.create();
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

class ElementObservers extends EventHandler{
	DistributedObserver dobs;
	DistributedManager observer;
	DistributedManager parentObserver;
	html.Element element;

	static create(e) => new ElementObservers(e);

	ElementObservers(this.dobs){
		this.observer = DistributedManager.create(this.dobs);
		this.parentObserver = DistributedManager.create(this.dobs); 

		this.observer.addHook('domReady');
		this.observer.addHook('domAdded');
		this.observer.addHook('domRemoved');
		this.observer.addHook('parentRemoved');
		this.observer.addHook('parentAdded');

		this.parentObserver.bindHook('childAdded',(n){
			// n = n.detail;
			if(Enums.filterItem(n.detail.addedNodes,this.element).length > 0)
				return this.observer.fireHook('domAdded',n);
		});

		this.parentObserver.bindHook('childRemoved',(n){
			// n = n.detail;
			if(Enums.filterItem(n.detail.removedNodes,this.element).length > 0)
				return this.observer.fireHook('domRemoved',n);
		});

	}

	void destroy(){
		this.dobs.destroy();
		this.observer.destroy();
		this.parentObserver.destroy();
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

	void observeElement(html.Element e,[Map a]){
		this.element = e;
		this.observer.observe(this.element,a);
	}

	void useParent(html.Element parent,[Map a,Function domInsertion(r,e)]){
		this.parentObserver.observe(parent,a);
		if(Valids.notExist(domInsertion)){
			if(!Valids.match(this.element.parent,parent)) return parent.append(this.element);
			this.fireEvent('domAdded',this.element);
			return null;
		};
		return domInsertion(this.element,parent);
	}

	void observe(html.Element e,{
          html.Element parent: null, 
          Map elemOptions:null, 
          Map parentOptions:null,
          Function insert:null}){
		this.observeElement(e,elemOptions);
		if(Valids.exist(parent)) this.useParent(parent,parentOptions,insert);
	}

	void bind(String name,Function n) => this.observer.bindHook(name,n);
	void bindOnce(String name,Function n) => this.observer.bindHookOnce(name,n);
	void unbind(String name,Function n) => this.observer.unbindHook(name,n);
	void unbindOnce(String name,Function n) => this.observer.unbindHookOnce(name,n);
	void bindWhenDone(String nm,Function n) => this.observer.bindWhenDone(nm,n);
	void unbindWhenDone(String nm,Function n) => this.observer.unbindWhenDone(nm,n);

}

class EventFactory{
	MapDecorator _hidden,factories;
	MapDecorator bindings;
	EventHandler handler;

	static create(n) => new EventFactory(n);

	EventFactory(this.handler){
		this._hidden = MapDecorator.create();
		this.factories = MapDecorator.create();
		this.bindings = MapDecorator.create();
	}

	void addFactory(String name,Function n(e)){
		this._hidden.add(name,n);
		this.factories.add(name,(n){
			this._hidden.get(name)(n);
		});
	}

	Function updateFactory(String name,Function n(e)){
		this._hidden.update(name,n);
	}

	void removeFactory(String name){
		this._hidden.destroy(name);
		this.factories.destroy(name);
	}

	Function getFactory(String name) => this.factories.get(name);

	bool hasFactory(String name) => this.factories.has(name);

	void fireFactory(String name,[dynamic n]) => this.hasFactory(name) && this.getFactory(name)(n);

	void bindFactory(String name,String ft){
		if(!this.factories.has(ft)) return null;
                /*if(this.bindings.has(name) && this.bindings.get(name).contains(ft)) return null;*/
		(this.bindings.has(name) ? this.bindings.get(name).add(ft) : this.bindings.add(name,[ft]));
		this.handler.bind(name,this.factories.get(ft));
	}

	void bindFactoryOnce(String name,String ft){
		if(!this.factories.has(ft)) return null;
		// (this.bindings.has(name) ? this.bindings.get(name).add(ft) : this.bindings.add(name,[ft]));
		this.handler.bindOnce(name,this.factories.get(ft));
	}

	void unbindFactory(String name,String ft){
		if(!this.factories.has(ft)) return null;
		(this.bindings.has(name) ? this.bindings.get(name).removeElement(this.factories.get(ft)) : null);
		this.handler.unbind(name,this.factories.get(ft));
	}

	void unbindFactoryOnce(String name,String ft){
		if(!this.factories.has(ft)) return null;
		this.handler.unbindOnce(name,this.factories.get(ft));
	}

	void unbindAllFactories(){
		this.bindings.onAll((name,list){
			list.forEach((f) => this.unbindFactory(name,f));
		});
	}

	void destroy(){
		this.unbindAllFactories();
		this._hidden.clear();
		this.factories.clear();
		this.handler = this._hidden = this.factories = null;
	}
}
