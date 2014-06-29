library taggables;

import 'dart:collection';
import 'dart:convert';
import 'package:bass/bass.dart';
import 'package:hub/hub.dart';
import 'dart:html' as html;

export 'package:bass/bass.dart';
export 'package:hub/hub.dart';

final _Empty = (e){};

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
		// this.bindMutation('DOMSubtreeModified');
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
		a = Funcs.switchUnless(a,{
			'attributes':true,
			'attributeOldValue': true,
			'subtree': true,
			'childList': true,
			'characterData':true,
			'characterDataOldValue':true
		});

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

class ElementObservers{
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
                this.bind(n,_Empty);
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

	void observe(html.Element e,{html.Element parent: null, Map elemOptions:null, Map parentOptions:null,Function insert:null}){
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

class TagNS{
	final MapDecorator blueprints = MapDecorator.create();
	String id;

	static create(n) => new TagNS(n);

	TagNS(String d){
		this.id = d.toLowerCase();
	}

	Function createTag(String tagName,TagRegistry r,[html.Element tag]){
		tagName = tagName.toLowerCase();
		if(!this.blueprints.has(tagName)) return null;
		var blueprint = this.blueprints.get(tagName);

		return (Function n(Function bp,Tag v,html.Element t)){
			var f = Tag.create(Funcs.switchUnless(tag,tagName),r);
			f.inprint();
			return n(blueprint,f,tag);
		};
	}

	Function inprintTag(Tag g){
		var tagName = g.tag;
		if(!this.blueprints.has(tagName)) return null;
		var blueprint = this.blueprints.get(tagName);

		return (Function n(Function bp,Tag v,html.Element t)){
			g.inprint();
			return n(blueprint,g,g.wrapper);
		};
	}

	void register(String tag,Function n(Tag g,Function n)){
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
	TagNS _dns;
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
		Taggables.defaultValidator.addTag(tag);
		nsg.register(tag,n);
                this._updateCache();
	}

	void unregister(String n,String tag){
                var nsg = this.ns(n);
		if(Valids.notExist(nsg)) return null;
		nsg.unregister(tag);
                this._updateCache(tag);
	}

	void makeDefault(String name){
		var nsg = this.ns(name);
		if(Valids.notExist(nsg)) return null;
		this._dns = nsg;
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

class Hook{
	String guid;
	TagRegistry registry;
	html.Element coreElement;
	DistributedObserver observer;
	ElementObservers observerManager;
	MapDecorator loadedTags;
	DisplayHook display;

	static Hook create([n,m]) => new Hook(n,m);

	static Hook bindWith([TagRegistry r,html.Element e,Function initLater]){
		e = Funcs.switchUnless(e,html.window.document.body);
		var inst = Hook.create(r);
		if(Valids.exist(initLater)){
			initLater(inst,({Map ops:null}){ inst.init(e,null,ops); });
			return inst;
		}
		return inst.init(e);
	}

	static Hook withObserver(DistributedObserver b,[TagRegistry r,html.Element e,Function initLater]){
		e = Funcs.switchUnless(e,html.window.document.body);
		var inst = Hook.create(r);
		if(Valids.exist(initLater)){
			initLater(inst,({Map ops:null}){ inst.init(e,null,ops); });
			return inst;
		}
		return inst.init(e);
	}

	Hook([TabRegistry reg,DistributedObserver ob]){
		this.registry = Funcs.switchUnless(reg,Taggables.core);
		this.observer = Funcs.switchUnless(ob,DistributedObserver.create());
		this.observerManager = ElementObservers.create(this.observer);

		this.guid = Hub.randomString(2,4);
		this.loadedTags = MapDecorator.create();	

		this.addEvent('__init__');
		this.addEvent('domReady');
		this.addEvent('beforedomReady');
		this.addEvent('afterdomReady');

		this.bindWhenDone("beforedomReady",(e){
			this.fireEvent('domReady',e);
		});

		this.bindWhenDone("domReady",(e){
			this.fireEvent('afterdomReady',e);
		});

		this.bind('__init__',(e){
			this.fireEvent('beforedomReady',e);
		});

		this.observerManager.addEvent('addNodeComplete');
		this.observerManager.addEvent('rmNodeComplete');

		this.observerManager.addEvent('tagError');
		this.observerManager.addEvent('tagAdded');
		this.observerManager.addEvent('tagRemoved');

		this.observerManager.bind('childAdded',(e){
			this.delegateRegistry(e);
		});

		this.observerManager.bind('childRemoved',(e){
			this.delegateRegistry(e);
		});

	}

	Hook init(html.Element core,[html.Element parent,Map pops,Function n]){
		this.coreElement = core;
		parent = Funcs.switchUnless(parent,this.coreElement.parent);
            
		pops = Enums.merge({
			'childList':true,
			'attributes':true,
			'attributeOldValue': true,
			'characterData': true,
			'characterDataOldValue': true
		},Funcs.switchUnless(pops,{}));

		this.observerManager.observe(this.coreElement,parent:parent,parentOptions:pops,insert:n);
		this.display = DisplayHook.create(this.coreElement.ownerDocument.window);

		this.afterInit();

		return this;
	}

	void afterInit(){
		this.delegateRegistryAdd(this.coreElement.children);
		this.fireEvent('__init__',true);
	}
        
	void delegateRegistry(event){
          if(this.coreElement != event.target) return null;
          if(event.detail.addedNodes.length > 0) 
              this.delegateRegistryAdd(event.detail.addedNodes,event);
          if(event.detail.removedNodes.length > 0) 
              this.delegateRegistryRemove(event.detail.removedNodes,event);
	}
        
	void delegateRegistryAdd(List<html.Element> tags,[event]){
		this._actionTrigger(tags,(tag){

			if(!(tag is html.Element)) return null;
			if(Valids.exist(tag.dataset['hooksync'])) return null;

                        var tagName = tag.tagName.toLowerCase(),
                            parent = tag.parent,
                            me = this.coreElement,
                            parentName = Valids.exist(parent) ? parent.tagName : null;
          
                        if(Valids.exist(parent)){
                          if(Taggables.core.providesTag(parentName) && parent != me)
                            return null;
                        }


                        if(!Taggables.core.providesTag(tagName)) 
                            return this.delegateRegistryAdd(tag.children,event);

                        
                        if(!this.loadedTags.has(tagName)) this.loadedTags.add(tagName,[]);

                        this._findTag(this.loadedTags.get(tagName),tag,(r,e){
                                this.observerManager.fireEvent('tagError',{
                                        'error':'attempt at adding already existing tag',
                                        'culprit': e,
                                        'culpritInstance': r,
                                });
                        },(a,err){
                                this.manufactureTag(tag,(tgi){
                                        tag.dataset['hooksync'] = this.guid;
                                        this.loadedTags.get(tagName).add(tgi);
                                        this.observerManager.fireEvent('tagAdded',tgi);
                                });
                        });
		},(err){
			var map = {'event':event,'err': err};
			this.observerManager.fireEvent('addNodeComplete',map);
		});
	}

	void delegateRegistryRemove(List<html.Element> tags,[event]){
		this._actionTrigger(tags,(tag){
			if(tag is! html.Element) return null;

			var tagName = tag.tagName.toLowerCase();


			if(this.loadedTags.has(tagName)) 
				this._findTag(this.loadedTags.get(tagName),tag,(r,e){
					Enums.yankValues(this.loadedTags.get(tagName),r).forEach((f){
						this.observerManager.fireEvent('tagRemoved',f);
					});
				});
		},(err){
			var map = {'event':event,'err': err};
			this.observerManager.fireEvent('rmNodeComplete',map);
		});
	}

	dynamic getEvent(String n) => this.observerManager.getEvent(n);

	void addEvent(String n,[Function m]){
		this.observerManager.addEvent(n,m);
	}

	void removeEvent(String n){
		this.observerManager.removeEvent(n);
	}

	void fireEvent(String n,dynamic a){
		this.observerManager.fireEvent(n,a);
	}

	void findTagNameIn(List<html.Element> a,String name,Function n,[Function m]){
		if(a.isEmpty) return null;
		Enums.eachAsync(a,(e,i,o,fn){
			if(e.tagName == name) n(e,name);
			return fn(null);
		},(_,err){
			if(Valids.exist(m)) return m(err);
		});
	}

	void _actionTrigger(List a,Function add,[Function ca]){
		if(a.isEmpty) return null;
		Enums.eachAsync(a,(e,i,o,fn){
			add(e);
			return fn(null);
		},(_,err){
			ca(err);
		});
	}

	void _findTag(List a,dynamic m,[Function ys,Function ns]){
		Enums.eachAsync(a,(e,i,o,fn){
			if(e.wrapper == m){
				if(Valids.exist(ys)) ys(e,m);
				return fn(true);
			}
			return fn(null);
		},(_,err){
			if(Valids.exist(ns)) ns(_,err);
		});
	}

	void _handleManufacturing(Function ns,Function n){
		return ns((bp,tg,e){
			bp(tg,([p]){
				var parent = Funcs.switchUnless(p,(Valids.exist(e.parentNode) ? e.parentNode : this.coreElement));
				tg.init(parent);
			});
			n(tg);
		});
	}

	void manufactureTag(html.Element tag,Function n){
		var tagName = tag.tagName.toLowerCase();
		var nsm = tag.dataset['ns'];

		if(Valids.notExist(nsm)) return this.registry.findProvider(tagName,(ns){
			this._handleManufacturing(ns.createTag(tagName,this.registry,tag),n);
		});

		var tg = this.registry.createTag(nsm,tagName,tag);
		if(Valids.exist(tg)) return this._handleManufacturing(tg,n);
	}

	dynamic addTag(Tag tag,[Function cm]){
		var tagName = tag.tag;

		if(!this.loadedTags.has(tagName)) this.loadedTags.add(tagName,[]);

		Enums.eachAsync(this.loadedTags.get(tagName),(e,i,o,fn){
			if(e == tag) return fn(true);
			return fn(null);
		},(_,err){
			if(err) return null;

			tag.wrapper.dataset['hooksync'] = this.guid;

			if(Valids.exist(tag.namespace) && this.registry.hasNS(tag.namespace)){
				var ns = this.registry.ns(tag.namespace);
				if(ns.has(tag.tag))
					return this._handleManufacturing(ns.inprintTag(tag),(t){
						this.loadedTags.get(tagName).add(t);
						this.observerManager.fireEvent('tagAdded',t);
						if(Valids.exist(cm)) cm(t);
					});
			};

			return this.registry.findProvider(tag.tag,(ns){
				this._handleManufacturing(ns.inprintTag(tag),(t){
					this.loadedTags.get(tagName).add(t);
					this.observerManager.fireEvent('tagAdded',t);
					if(Valids.exist(cm)) cm(t);
				});
			},(g){
				var parent = Valids.exist(g.wrapper.parentNode) ? g.wrapper.parentNode : this.coreElement;
				this.loadedTags.get(tagName).add(tag);
				this.observerManager.fireEvent('tagAdded',tag);
				if(Valids.exist(cm)) cm(t);
				tag.init(parent);
			});

		});

		return tag;
	}

	Tag make(String ns,String tag,[Function cm]){
		return this.addTag(this.registry.createTag(ns,tag),cm);
	}

	void removeTag(Tag tag){
		var tagName = tag.tag;

		if(!this.loadedTags.has(tagName)) return null;

		var list = this.loadedTags.get(tagName);

		if(list.isEmpty) return null;

		Enums.yankValues(list,tag).forEach((f){
			this.observerManager.fireEvent('tagRemoved',f);
		});
	}

	void getTags(String tagName){
		return this.loadedTags.get(tagName.toLowerCase());
	}

	bool hasTagIn(String tagName,Tag g){
		if(!this.loadedTags.has(tagName.toLowerCase())) return false;
		return this.getTags(tagName).contains(g);
	}

	List hasTag(Tag g,[Function n]){
		var list;
		if(this.loadedTags.storage.isEmpty) return list;
		Enums.eachAsync(this.loadedTags.storage,(e,i,o,fn){
			if(this.hasTagIn(i,v)){
				list = e;
				if(Valids.exist(n)) n(e);
				fn(true);
			};
			return false;
		});
		return list;
	}

	void destroy(){
		this.loadedTags.on((v,k){
			k.forEach((f) => f.destroy());
			k.clear();
		});
		this.loadedTags.clear();
		this.observerManager.destroy();
		this.observer.destroy();
		if(Valids.exist(this.display)) this.display.stop();
	}

	void bind(String name,Function n) => this.observerManager.bind(name,n);
	void unbind(String name,Function n) => this.observerManager.unbind(name,n);
	void bindOnce(String name,Function n) => this.observerManager.bindOnce(name,n);
	void unbindOnce(String name,Function n) => this.observerManager.unbindOnce(name,n);
	void bindWhenDone(String nm,Function n) => this.observerManager.bindWhenDone(nm,n);
	void unbindWhenDone(String nm,Function n) => this.observerManager.unbindWhenDone(nm,n);
}

class Tag extends EventHandler{
	bool _sealedShadow = false, _ready = false, _inprint = false;
	String tag,tagNS;
	MapDecorator sharedData;
	MapDecorator atomics;
	Hook observer;
	html.DocumentFragment _shadowDoc;
	html.Element wrapper,preContent,style;
	EventFactory factories,shadowfactories;
	DisplayHook display;
	BassNS styleSheet;
	BassFormatter cssf;


	static create(n,m){
		if(n is html.Element){
			if(m is Hook) return new Tag.elem(n,hook: m);
			if(m is TagRegistry) return new Tag.elem(n,registry: m);
		}
		if(n is String){
			if(m is Hook) return new Tag(n,hook: m);
			if(m is TagRegistry) return new Tag(n,registry: m);
		}
	}

	Tag.elem(html.Element tg,{TagRegistry registry: null, Hook hook: null}){
	  if(Valids.notExist(registry) && Valids.notExist(hook)) throw "supply either a hook or registery please";

	  this.wrapper = tg;
	  this.tag = tg.tagName.toLowerCase();

	  if(Valids.exist(registry)) this.observer = Hook.create(registry);
	  else this.observer = hook;

	  Taggables.defaultValidator.addTag(this.wrapper.tagName);
	  this.beforeInit();
	}

	Tag(String tg,{TagRegistry registry: null, Hook hook: null}){
	  if(Valids.notExist(registry) && Valids.notExist(hook)) throw "supply either a hook or registery please";

	  this.tag = tg.toLowerCase();
	  this.wrapper = Taggables.createElement(this.tag);

	  if(Valids.exist(registry)) this.observer = Hook.create(registry);
	  else this.observer = hook;

	  Taggables.defaultValidator.addTag(this.wrapper.tagName);
	  this.beforeInit();
	}

	String get namespace => this.tagNS;
	html.DocumentFragment get shadow => this._shadowDoc;

	void inprint(){
		if(this._inprint) return;
		this._inprint = true;
	}

	bool get inprinted => !!this._inprint;
        html.Element get root => this.wrapper;
	MapDecorator get sd => this.sharedData;

        void sealShadow() => this._sealedShadow = true;
        void unsealShadow() => this._sealedShadow = false;
        bool get isShadowSealed => !!this._sealedShadow;

	void beforeInit(){
	  if(!!this._ready) return null;
	  this._ready = true;
	  this.factories = EventFactory.create(this);
	  this.shadowfactories = EventFactory.create(this);
	  this.sharedData = MapDecorator.create();
	  this.atomics = MapDecorator.create();
	  this._shadowDoc = new html.DocumentFragment();

	  this.style = Taggables.createElement('style');
	  this.preContent = new html.Element.tag('content');
	  this.preContent.children.addAll(this.wrapper.children);

	  this.tagNS = this.wrapper.dataset["ns"];

	  var id = this.hasAttr('id') ? this.attr('id') : null;
	  if(Valids.notExist(id)){ 
	  	id = "${this.tag}-${Hub.randomString(2,5)}"; 
	  	this.attr('id',id);
	  }

          this.addAtom('myCSS',this.root.getComputedStyle());
          this.addAtom('parentCSS',null);
          if(Valids.exist(this.root.parent)) 
            this.atom('parentCSS').changeHandler(this.root.parent.getComputedStyle());


	  this.styleSheet = Bass.NS(id);
	  this.cssf = this.styleSheet.css();
	  this.style.attributes['id'] = Funcs.combineStrings(id,'-style');
	  this.style.dataset['tag-id'] = this.tag;
	  this.style.attributes['type'] = 'text/css';

	  //open dom update and teardown events for public use
	  this.addEvent('update');
	  this.addEvent('updateCSS');
	  this.addEvent('updateDOM');
	  this.addEvent('teardownDOM');
	  //ghost events for internal use;
	  this.addEvent('_updateLive');
	  this.addEvent('_teardownLive');

	  this.factories.addFactory('updateDOM',(e){ });
	  this.factories.addFactory('teardownDOM',(e){});
	  this.factories.addFactory('teardown',(e) => this.root.setInnerHtml(""));

	  this.cssf.bind((m){
              this.style.text = m;
	  });

	  this.shadowfactories.addFactory('update',(e){
	  	this.fireEvent('teardownDOM',e);
	  });

	  this.shadowfactories.addFactory('updateCSS',(e){
	  	this.styleSheet.compile();
	  });

	  this.shadowfactories.addFactory('updateLive',(e){
              if(!this.isShadowSealed) return null;
              var clone = this.shadow.clone(true);
              this.wrapper.append(clone);
	  });

	  this.shadowfactories.addFactory('teardownLive',(e){
	  	if(!this.isShadowSealed) return null;
                this.wrapper.setInnerHtml("");
	  });

	  this.bind('updateCSS',this.shadowfactories.getFactory('updateCSS'));
	  this.bind('_updateLive',this.shadowfactories.getFactory('updateLive'));
	  this.bind('_teardownLive',this.shadowfactories.getFactory('teardownLive'));
	  this.bind('domReady',this.shadowfactories.getFactory('update'));
	  this.bind('update',this.shadowfactories.getFactory('update'));
  
          this.bind('updateDOM',this.getFactory('updateDOM'));
          this.bind('teardownDOM',this.getFactory('teardownDOM'));

	  this.bind('domadded',this.shadowfactories.getFactory('update'));
	  this.bind('domremoved',this.getFactory('teardown'));

	  this.bindWhenDone('_teardownLive',(e){
	  	this.fireEvent("_updateLive",e);
  	  });

	  this.bindWhenDone('_updateLive',(e){ 
	  	this.fireEvent('updateCSS',e);
	  	this.fireEvent('updateDOM',e);
  	  });

	  this.bindWhenDone('teardownDOM',(e){ 
	  	this.fireEvent('_teardownLive',e); 
	  });
          
	  this.shadow.setInnerHtml(this.preContent.innerHtml);
	}

	void init(html.Element parent,[Function n,Maps ops,int ms]){
                ms = Funcs.switchUnless(ms,500);
		var head = parent.ownerDocument.query('head');
		head.insertBefore(this.style,head.firstChild);
                if(Valids.notExist(this.root.parent) || (Valids.exist(this.root.parent) && this.root.parent != parent)){
                    this.atom('parentCSS').changeHandler(parent.getComputedStyle());
                    this.atom('parentCSS').checkAtomics();
                }
		this.observer.init(this.wrapper,parent,ops,n);
		this.display = DisplayHook.create(parent.ownerDocument.window);
                this.display.scheduleEvery(ms,(e){ this.atomics.onAll((v,k) => k.checkAtomics()); });
	}
	
	html.Element get parent => this.wrapper.parent;
	
        void addAtom(String n,Object b) => this.atomics.add(n,FunctionalAtomic.create(b));
        void removeAtom(String n) => this.atomics.has(n) && this.atomics.destroy(n).destroy();
        FunctionalAtomic atom(String n) => this.atomics.get(n);

        FunctionalAtomic get parentAtom => this.atom('parentCSS');
        FunctionalAtomic get myAtom => this.atom('myCSS');

        void startAtoms() => this.display.run();
        void stopAtoms() => this.display.stop();

	void bind(String name,Function n) => this.observer.bind(name,n);
	void bindOnce(String name,Function n) => this.observer.bindOnce(name,n);
	void unbind(String name,Function n) => this.observer.unbind(name,n);
	void unbindOnce(String name,Function n) => this.observer.unbindOnce(name,n);
	void bindWhenDone(String nm,Function n) => this.observer.bindWhenDone(nm,n);
	void unbindWhenDone(String nm,Function n) => this.observer.unbindWhenDone(nm,n);

	void addFactory(String name,Function n(e)) => this.factories.addFactory(name,n);
	Function updateFactory(String name,Function n(e)) => this.factories.updateFactory(name,n);
	Function getFactory(String name) => this.factories.getFactory(name);
	bool hasFactory(String name) => this.factories.hasFactory(name);

	void fireFactory(String name,[dynamic n]) => this.factories.fireFactory(name)(n);
	void bindFactory(String name,String ft) => this.factories.bindFactory(name,ft);
	void bindFactoryOnce(String name,String ft) => this.factories.bindFactoryOnce(name,ft);
	void unbindFactory(String name,String ft) => this.factories.unbindFactory(name,ft);
	void unbindFactoryOnce(String name,String ft) => this.factories.unbindFactoryOnce(name,ft);

        void createFactoryEvent(String ev,String n){
            this.addEvent(ev);
            this.bindFactory(ev,n);
        }

        void destroyFactoryEvent(String ev,String n){
          this.unbindFactory(ev,n);
          this.removeEvent(ev);
        }

        dynamic createShadowElement(String n,[String content]){
            var elem = Taggables.createElement(n);
            if(Valids.exist(content)) elem.setInnerHtml(content);
            Taggables.defaultValidator.addTag(elem.tagName);
            this.shadow.append(elem);
            return elem;
        }

        dyamic createShadowHtml(String markup){
            var elem = Taggables.createHtml(markup);
            Taggables.defaultValidator.addTag(elem.tagName);
            this.shadow.append(elem);
            return elem;

        }

	dynamic createElement(String n,[String content]){
            var elem = Taggables.createElement(n);
            if(Valids.exist(content)) elem.setInnerHtml(content);
            Taggables.defaultValidator.addTag(elem.tagName);
            this.root.append(elem);
            return elem;
	}

	dynamic createHtml(String markup){
            var elem = Taggables.createHtml(markup);
            Taggables.defaultValidator.addTag(elem.tagName);
            this.root.append(elem);
            return elem;
	}
	
	dynamic queryParent(n,[v]) => Valids.exist(this.parent) ? Taggables.queryElem(this.parent,n,v) : null;
	dynamic queryAllParent(n,[v]) => Valids.exist(this.parent) ? Taggables.queryAllElem(this.parent,n,v) : null;

	bool parentHasAttr(String n) => Valids.exist(this.parent) ? this.parent.attributes.containsKey(n) : false;	
	bool parentHasData(String n) => Valids.exist(this.parent) ? this.parent.dataset.containsKey(n) : false;
		
        dynamic get cssSheet => this.styleSheet;

        void css(Map m){
          return this.styleSheet.sel(this.tag,m);
        }

        void modCSS(Map m){
          return this.styleSheet.updateSel(this.tag,m);
        }

	dynamic getParentCSS(List a){
	  return Taggables.getCSS(this.parent,a);
	}
	
	dynamic getCSS(List a){
	  return Taggables.getTagCSS(this,a);
	}
	
	dynamic parentAttr(String n,[dynamic val]){
	    if(Valids.notExit(this.parent)) return null;
	    if(Valids.notExist(val)) return this.parent.getAttribute(n);
	    return this.parent.attributes[n] = val;
	}

	dynamic parentData(String n,[dynamic val]){
		if(Valids.notExit(this.parent)) return null;
		if(Valids.notExist(val)) return this.parent.dataset[n];
		return this.parent.dataset[n] = val;
	}

	dynamic fetchParentData(String n,Function m){
		var d = this.parentData(n);
		if(Valids.exist(d)) return m(d);
	}	
	
	dynamic query(n,[v]) => Taggables.query(this,n,v);
	dynamic queryAll(n,[v]) => Taggables.queryAll(this,n,v);

	dynamic queryShadow(n,[v]) => Taggables.queryShadow(this,n,v);
	dynamic queryShadowAll(n,[v]) => Taggables.queryShadowAll(this,n,v);

	bool hasAttr(String n) => this.wrapper.attributes.containsKey(n);
	
	bool hasData(String n) => this.wrapper.dataset.containsKey(n);
	
	dynamic attr(String n,[dynamic val]){
		if(Valids.notExist(val)) return this.wrapper.getAttribute(n);
		return this.wrapper.attributes[n] = val;
	}

	dynamic data(String n,[dynamic val]){
		if(Valids.notExist(val)) return this.wrapper.dataset[n];
		return this.wrapper.dataset[n] = val;
	}

	dynamic fetchData(String n,Function m){
		var d = this.data(n);
		if(Valids.exist(d)) return m(d);
	}

	void addEvent(staticring n,[Function m]){
		this.observer.addEvent(n,m);
	}

	void removeEvent(String n){
		this.observer.removeEvent(n);
	}

	void fireEvent(String n,dynamic a){
		this.observer.fireEvent(n,a);
	}

	void destroy(){
	  this._ready = false;
          this.stopAtoms();
          this.display.destroy();
	  this.observer.destroy();
	  this.factories.destroy();
	  this.sharedData.clear();
	  this.sharedData = this.factories = this.document = this.observer =  this.tagNS = null;
	  this._shadowDoc = this._liveDoc = null;
	}

	String toString() => "tag#${this.tag} observer#${this.observer.guid}";
}

class TagUtil{
  
    static int fromPx(String px){
      return int.parse(px.replaceAll('px',''));
    }

    static String toPx(int px) => "${px}px";
}

class Taggables{

	static Log debug = Log.create(null,null,"Taggables#({tag}):\n\t{res}\n");
	static Bass css = Bass.B;
	static RuleSet bassRules = Bass.R;
	static TagRegistry core = TagRegistry.create();
	static CustomValidator defaultValidator = new CustomValidator();
	
	static dynamic getTagCSS(Tag g,List a){
	  return Taggables.getCSS(g.wrapper,a);
	}
	
	static dynamic getCSS(html.Element n,List a){
	  var res = {};
	  attr.forEach((f){
	     res[f] = n.style.getProperty(f);
	  });
	  return MapDecorator.create(res);
	}
	
	static void tagCss(Tag n,String query,Map m){
		var core = n.shadow.querySelectorAll(query);
		if(Valids.notExist(core) || core.isEmpty) return null;
		core.forEach((f){
			Taggables.cssElem(f,m);
		});
	}

	static dynamic queryElem(html.Element d,String query,[Function v]){
		var q = d.querySelector(query);
		if(Valids.exist(q) && Valids.exist(v)) v(q);
		return q;
	}

	static dynamic queryAllElem(html.Element d,String query,[Function v]){
		var q = d.querySelectorAll(query);
		if(Valids.exist(q) && Valids.exist(v)) v(q);
		return q;
	}

	static dynamic query(Tag n,String query,[Function v]){
		return Taggables.queryElem(n.root,query,v);
	}

	static dynamic queryAll(Tag n,String query,[Function v]){
		return Taggables.queryAllElem(n.root,query,v);
	}

	static dynamic queryShadow(Tag n,String query,[Function v]){
		return Taggables.queryElem(n.shadow,query,v);
	}

	static dynamic queryShadowAll(Tag n,String query,[Function v]){
		return Taggables.queryAllElem(n.shadow,query,v);
	}

	static void cssElem(html.Element n,Map m){
	    m.forEach((k,v){
		n.style.setProperty(k,v);
	    });
	}

	static html.Element createElement(String n){
		Taggables.defaultValidator.addTag(n);
		return html.window.document.createElement(n);
	}

	static html.Element createHtml(String n){
		return new html.Element.html(n,validator: Taggables.defaultValidator.rules);
	}

	static html.Element liquify(html.Element n){
		var b = Taggables.createElement('liquid');
		b.setInnerHtml(n.innerHtml,validator: Taggables.defaultValidator.rules);
		return b;
	}

	static String deliquify(html.Element l,html.Element hold){
		if(l.tagName.toLowerCase() == 'liquid'){
			hold.setInnerHtml(l.innerHtml,validator: Taggables.defaultValidator.rules);
		}
	}
}

