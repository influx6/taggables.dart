library taggables;

import 'dart:collection';
import 'dart:convert';
import 'package:hub/hubclient.dart';
import 'dart:html' as html;

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
		return this.hooks.get(name).emit(n);
	}

	void bind(String name,Function n){
		if(!this.hooks.has(name)) return null;
		return this.hooks.get(name).on(n);
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

			var type = n.type.toLowerCase();
			Funcs.when(Valids.match(type,'attributes'),(){

				if(Valids.exist(n.attributeName)){
					this.hooks.fireHook(this.hasAttribute(n.attributeName) 
						? 'attributeChange' : 'attributeRemoved',n);
				}

				if(Valids.exist(n.attributeNamespace)){
					this.hooks.fireHook(this.hasAttributeNS(n.attributeNamespace) 
						? 'attributeChange' : 'attributeRemoved',n);
				}

			});

			Funcs.when(Valids.match(type,'childlist'),(){
				if(n.addedNodes.length > 0) return this.hooks.fireHook('childAdded',n);
				if(n.removedNodes.length > 0) return this.hooks.fireHook('childRemoved',n);
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


	void bindMutation(Function n) => this.observer.bind(n);
	void bindMutationOnce(Function n) => this.observer.bindOnce(n);
	void unbindMutation(Function n) => this.observer.unbind(n);
	void unbindMutationOnce(Function n) => this.observer.unbindOnce(n);

	void addHook(String name,[n]) => this.hooks.addHook(name,n);
	void fireHook(String name,n) => this.hooks.fireHook(name,n);
	void removeHook(String name) => this.hooks.removeHook(name);

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
			if(Enums.filterItem(n.addedNodes,this.element).length > 0)
				return this.observer.fireHook('domAdded',n);
		});

		this.parentObserver.bindHook('childRemoved',(n){
			if(Enums.filterItem(n.removedNodes,this.element).length > 0)
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
	}

	void removeEvent(String n){
		this.observer.removeHook(n);
	}

	void fireEvent(String n,dynamic a){
		this.observer.fireHook(n,a);
	}

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

class Tag extends EventHandler{
	String tag,tagID,tagNS;
	Hook observer;
	Pipe pipe;
	html.DocumentFragment document;
	html.Element wrapper,preContent;
	MapDecorator sharedData;
	EventFactory factories;
	bool _ready = false;
	bool _inprint = false;

	static create(n,m) => new Tag(n,m);

	Tag(dynamic tg,dynamic ob){
	   if(ob is html.Element){
	   	 var elem = ob;
	   	 ob = tg;
	   	 tg = elem;
	   }

	  if(ob is Hook) this.observer = hook;
	  if(ob is TagRegistry) this.observer = Hook.create(ob);
	  if(tg is String){
		  this.tag = tg.toLowerCase();
		  this.wrapper = html.window.document.createElement(this.tag);
	  }
	  if(tg is html.Element){
		  this.wrapper = tg;
		  this.tag = tg.tagName.toLowerCase();
	  }

	  if(tg is! html.Element) throw "$tg must be of class ${html.Element}";
	  if(ob is! Hook && ob is! TagRegistry) throw "$ob must be of class ${TagRegistry} or ${Hook}";

	  this.beforeInit();
	}

	dynamic query(n,[v]) => Taggables.query(this,n,v);

	dynamic queryAll(n,[v]) => Taggables.queryAll(this,n,v);

	void css(Map m,[String q]){
		if(Valids.exist(q)) return Taggables.tagCss(this,q,m);
		return Taggables.cssElem(this.wrapper,m);
	}

	String get pipeID => this.tagID;
	String get namespace => this.tagNS;

	void inprint(){
		if(this._inprint) return;
		this._inprint = true;
	}

	bool get inprinted => !!this._inprint;

	MapDecorator get sd => this.sharedData;

	void beforeInit(){
	  if(!!this._ready) return null;
	  this._ready = true;
	  this.factories = EventFactory.create(this);
	  this.sharedData = MapDecorator.create();
	  this.document = new html.DocumentFragment();

	  this.tagID = this.wrapper.dataset["pipeid"];
	  this.tagNS = this.wrapper.dataset["tagns"];

	  this.preContent = new html.Element.tag('content');
	  this.preContent.children.addAll(this.wrapper.children);

	  if(Valids.exist(this.tagID)){
		this.tagID = this.tagID.toLowerCase();
		this.pipe = Pipe.create(this.tagID);
	  }

	  this.factories.addFactory('updateDOM',(e){
	  	this.fireEvent('teardownDOM',e);
		this.wrapper.append(this.document);
	  });

	  this.factories.addFactory('teardownDOM',(e){
		// this.wrapper.setInnerHtml("");
		print("#doc ${this.document.innerHtml}");
		this.document.remove();
		print("#doc afterrm ${this.document.innerHtml}");
	  });

	  this.addEvent('updateDOM');
	  this.addEvent('teardownDOM');

	  // this.bind('domAdded',this.getFactory('updateDOM'));
	  // this.bind('domRemoved',this.getFactory('teardownDOM'));
	  this.bind('updateDOM',this.getFactory('updateDOM'));
	  this.bind('teardownDOM',this.getFactory('teardownDOM'));

	  this.bindFactory('domReady','updateDOM');

	}

	void init(html.Element parent,[Function n,Maps ops]){
		this.observer.init(this.wrapper,parent,ops,n);
	}

	void bind(String name,Function n) => this.observer.bind(name,n);
	void bindOnce(String name,Function n) => this.observer.bindOnce(name,n);
	void unbind(String name,Function n) => this.observer.unbind(name,n);
	void unbindOnce(String name,Function n) => this.observer.unbindOnce(name,n);

	void addFactory(String name,Function n(e)) => this.factories.addFactory(name,n);
	Function updateFactory(String name,Function n(e)) => this.factories.updateFactory(name,n);
	Function getFactory(String name) => this.factories.getFactory(name);
	bool hasFactory(String name) => this.factories.hasFactory(name);
	void fireFactory(String name,[dynamic n]) => this.factories.fireFactory(name)(n);
	void bindFactory(String name,String ft) => this.factories.bindFactory(name,ft);
	void bindFactoryOnce(String name,String ft) => this.factories.bindFactoryOnce(name,ft);
	void unbindFactory(String name,String ft) => this.factories.unbindFactory(name,ft);
	void unbindFactoryOnce(String name,String ft) => this.factories.unbindFactoryOnce(name,ft);

	dynamic attr(String n,[dynamic val]){
		if(Valids.notExist(val)) return this.wrapper.getAttribute(n);
		return this.wrapper.attributes[n] = val;
	}

	dynamic data(String n,[dynamic val]){
		if(Valids.notExist(val)) return this.wrapper.dataset[n];
		return this.wrapper.dataset[n] = val;
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
	  this.observer.destroy();
	  this.factories.destroy();
	  this.sharedData.clear();
	  this.pipe.destroy();
	  this.sharedData = this.factories = this.document = this.observer = this.tagID = this.tagNS = null;
	}

	String toString() => "tag#${this.tag} observer#${this.observer.guid}";
}

class _HookGenerator{
	DistributedObserver dist;

	_HookGenerator(this.dist);

	Hook create(html.Element e,[Map bp]){
		return new Hook.withObserver(e,this.dist,bp);
	}
}

class Pipe{
	String id;
	dynamic pin,pout;
	dynamic out = Hub.createDistributor('pipe-out');

	static create(String id) => new Pipe(id);

	Pipe(this.id){
		this.pout = Hub.createDistributor('pipe-out');
		this.pin = Hub.createDistributor('pipe-in');
	}

	bool get active => Valids.exist(this.pout) && Valids.exist(this.pin);

	void sendOut(dynamic n){
		if(!this.active) return null;
		this.pout.emit(n);
	}

	void sendIn(dynamic n){
		if(!this.active) return null;
		this.pin.emit(n);
	}

	void recieve(Function m){
		if(!this.active) return null;
		this.pin.on(m);
	}

	void recieveOnce(Function m){
		if(!this.active) return null;
		this.pin.once(m);
	}

	void unrecieve(Function m){
		if(!this.active) return null;
		this.pin.off(m);
	}

	void unrecieveOnce(Function m){
		if(!this.active) return null;
		this.pin.offOnce(m);
	}

	void destroy(){
		if(!this.active) return null;
		this.pin.free();
		this.pout.free();
		this.pin = this.pout = null;
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
		this.blueprints.destroy(tag);
	}

	void destroy(){
		this.blueprints.clear();
	}

	bool has(String nm) => this.blueprints.has(nm.toLowerCase());

	String toString() => this.blueprints.toString();

}

class TagRegistry{
	MapDecorator namespace;
	TagNS _dns;

	static create() => new TagRegistry();

	TagRegistry(){
		this.namespace = MapDecorator.create();
	}

	void addNS(String ns) => this.namespace.add(ns.toLowerCase(),TagNS.create(ns));
	void removeNS(String ns) => this.namespace.destroy(ns.toLowerCase()).destroy();
	TagNS ns(String n) => this.namespace.get(n.toLowerCase());

	void register(String s,String tag,Function n){
		if(!this.namespace.has(s.toLowerCase())) this.addNS(s);
		var nsg = this.ns(s);
		if(Valids.notExist(nsg)) return null;
		nsg.register(tag,n);
	}

	void unregister(String n,String tag){
		var nsg = this.ns(n);
		if(Valids.notExist(nsg)) return null;
		nsg.unregister(tag);
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
		var ns;
		Enums.eachAsync(this.namespace.storage,(e,i,o,fn){
			if(e.has(tagName)){
				if(Valids.exist(n)) n(e);
				ns = e;
				return fn(true);
			}
			return fn(null);
		},(_,err){
			if(Valids.notExist(err) && Valids.exist(m)) m(tagName);
		});

		return ns;
	}

	String toString() => this.namespace.toString();
}

class Hook{
	String guid;
	TagRegistry registry;
	html.Element coreElement;
	DistributedObserver observer;
	ElementObservers observerManager;
	MapDecorator loadedTags;

	static TagRegistry core = TagRegistry.create();

	static Hook create([n,m]) => new Hook(n,m);

	static Hook bindWith([TagRegistry r,html.Element e,Function initLater]){
		e = Funcs.switchUnless(e,html.window.document.body);
		var inst = Hook.create(r);
		if(Valids.exist(initLater)){
			initLater(inst,(){ inst.init(e); });
			return inst;
		}
		return inst.init(e);
	}

	static Hook withObserver(DistributedObserver b,[TagRegistry r,html.Element e,Function initLater]){
		e = Funcs.switchUnless(e,html.window.document.body);
		var inst = Hook.create(r);
		if(Valids.exist(initLater)){
			initLater(inst,(){ inst.init(e); });
			return inst;
		}
		return inst.init(e);
	}

	Hook([TabRegistry reg,DistributedObserver ob]){
		this.registry = Funcs.switchUnless(reg,Hook.core);
		this.observer = Funcs.switchUnless(ob,DistributedObserver.create());
		this.observerManager = ElementObservers.create(this.observer);

		this.guid = Hub.randomString(2,4);
		this.loadedTags = MapDecorator.create();	

		this.addEvent('domReady');

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
		// if(Valids.notExist(core.parentNode)) 
		// 	return throw "Hook binding element must already have been added to the dom before using it";

		this.coreElement = core;
		parent = Funcs.switchUnless(parent,this.coreElement.parent);
		pops = Funcs.switchUnless(pops,{
			'childList':true,
			'attributes':true,
			'attributeOldValue': true,
			'characterData': true,
			'characterDataOldValue': true
		});

		this.observerManager.observe(this.coreElement,parent:parent,parentOptions:pops,insert:n);

		this.afterInit();

		return this;
	}

	void afterInit(){
		this.delegateRegistryAdd(this.coreElement.children);
		this.fireEvent('domReady',true);
	}

	void addEvent(staticring n,[Function m]){
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
		var nsm = tag.dataset['tagns'];

		if(Valids.notExist(nsm)) return this.registry.findProvider(tagName,(ns){
			this._handleManufacturing(ns.createTag(tagName,this.registry,tag),n);
		});

		var tg = this.registry.createTag(nsm,tagName,tag);
		if(Valids.exist(tg)) return this._handleManufacturing(tg,n);
	}

	void delegateRegistryAdd(List<html.Element> tags,[event]){
		this._actionTrigger(tags,(tag){

			if(!(tag is html.Element)) return null;
			if(Valids.exist(tag.dataset['hooksync'])) return null;

			var tagName = tag.tagName.toLowerCase();

			// if(!this.blueprints.has(tagName)) return null;

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

			// if(!this.registry.has(tagName)) return null;

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

	void delegateRegistry(event){
		if(this.coreElement != event.target) return null;
		if(event.addedNodes.length > 0) this.delegateRegistryAdd(event.addedNodes,event);
		if(event.removedNodes.length > 0) this.delegateRegistryRemove(event.removedNodes,event);
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
	}

	void bind(String name,Function n) => this.observerManager.bind(name,n);
	void unbind(String name,Function n) => this.observerManager.unbind(name,n);
	void bindOnce(String name,Function n) => this.observerManager.bindOnce(name,n);
	void unbindOnce(String name,Function n) => this.observerManager.unbindOnce(name,n);
}

class Taggables{

	static void tagCss(Tag n,String query,Map m){
		var core = n.document.querySelectorAll(query);
		if(Valids.notExist(core) || core.isEmpty) return null;
		core.forEach((f){
			Taggables.cssElem(f,m);
		});
	}

	static dynamic query(Tag n,String query,[Function v]){
		var q = n.document.querySelector(query);
		if(Valids.exist(q) && Valids.exist(v)) v(q);
		return q;
	}

	static dynamic queryAll(Tag n,String query,[Function v]){
		var q = n.document.querySelectorAll(query);
		if(Valids.exist(q) && Valids.exist(v)) v(q);
		return q;
	}

	static void cssElem(html.Element n,Map m){
		m.forEach((k,v){
			n.style.setProperty(k,v);
		});
	}
}