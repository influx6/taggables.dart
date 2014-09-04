library taggables;

import 'dart:collection';
import 'dart:convert';
import 'package:bass/bass.dart';
import 'package:hub/hub.dart';
import 'package:streamable/streamable.dart';
import 'dart:html' as html;

export 'package:bass/bass.dart';
export 'package:hub/hub.dart';

part 'core.dart';

final Core = TagUtil.core;
final DispatchEvent = (dynamic n,String t,[dynamic msg]){
  if(n is html.Element) return TagUtil.dispatchEvent(n,t,msg);
  if(n is Tag) return TagUtil.dispatchEvent(n.root,t,msg);
};
final DeliverMessage = (bool isMass,String sel,String type,dynamic msg,[doc]){
  if(isMass) return TagUtil.deliverMassMessage(sel,type,msg,doc);
  return TagUtil.deliverMessage(sel,type,msg,doc);
};

class TagDispatcher extends Dispatch{
    final MapDecorator stores = new MapDecorator<String,TagStore>();
    final html.Element root;
    ElementObservers observer;

    MapDecorator actions = MapDecorator.useMap({
      'added':0,
      'removed':1,
      'attribute':2
    });

    static create(r,[d]) => new TagDispatcher(r,d);
    TagDispatcher(this.root,[DistributedObserver d]): super(){
      this.observer = ElementObservers.create(Valids.exist(d) ? d : DistributedObserver.create());

      this.observer.bind('childAdded',(e){
        var nodes = e.detail.addedNodes;
        nodes.forEach((f){
          var name = e.tagName;
          this.dispatch({
            'message':name,
            'action': TagDispatcher.actions.get('added'),
            'node': f,
          });
        });
      });

      this.observer.bind('childRemoved',(e){
        var nodes = e.detail.removedNodes;
        nodes.forEach((f){
          var name = e.tagName;
          this.dispatch({
            'message':name,
            'action': TagDispatcher.actions.get('removed'),
            'node': f,
          });
        });
      });

    }

    TagStore createStore(String tg){
      if(this.stores.has(tg)) return this.stores.get(tg);
      var store = TagStore.create(tg,this);
      this.stores.add(tg,store);
      return store;
    }

}

class TagHouse{
  final MapDecorator storehouse = new MapDecorator<String,Tag>();
  final TagStore store;

  static create(s) => new TagHouse(s);
  TagHouse(this.store);

  Tag delegate(html.Element tag){
    var taghash = tag.hashCode.toString();
    if(this.storehouse.has(taghash)) return this.storehouse.get(taghash);
    var tag = Tag.create(tag);

  }

}

class TagStore extends SingleStore{
  String tagName;
  TagRegistry registry;
  DispatchWatcher tagwatch;
  TagHouse house;

  static create(ts,d,[t]) => new TagStore(ts,d,t);

  TagStore(String tagName,TagDispatcher tags,[TagRegistry t]): super(tags), tagwatch = tags.watch(tagName){
    this.tagName  = tagName;
    t = Funcs.switchUnless(t,TagUtil.core);
    this.registry = t;
    this.house = TagHouse.create(this);
    this.tagwatch = this.dispatch.watch(tagName);

    /*this.tagwatch.listen*/
  }

  void delegate(Map v){ return null; }

  void delegateRequest(){
  /*  ms = Funcs.switchUnless(ms,300);*/
  /*  this.display.scheduleEvery(ms,this._displayhook);*/
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
		TagUtil.defaultValidator.addTag(tag);
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
		this.registry = Funcs.switchUnless(reg,TagUtil.core);
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
                          if(TagUtil.core.providesTag(parentName) && parent != me)
                            return null;
                        }


                        if(!TagUtil.core.providesTag(tagName)) 
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
  final String guid = Hub.randomString(4).replaceAll(TagUtil.digitReg,'').replaceAll('-','');
  final String tagName;
  String tagNS;
  String _cssId;
  final html.Element root;
  ElementObservers observer;
  html.DocumentFragment shadow;
  html.StyleElement style;
  html.Element precontent;
  EventFactory factories,shadowfactories;
  MapDecorator atomics,sd,options;
  QueryShell $,$$;
  CSS cssheet;
  SVG ink;

  static create(r,[ns]) => new Tag(r,ns);

  Tag(html.Element root,[this.tagNS,DistributedObserver dist]): this.root = root,this.tagName = root.tagName.toLowerCase(){
    TagUtil.defaultValidator.addTag(this.tagName);
    this.observer = ElementObservers.create(Valids.exist(dist) ? dist : DistributedObserver.create());
    this.factories = EventFactory.create(this);
    this.shadowfactories = EventFactory.create(this);
    this.sd = MapDecorator.create();
    this.atomics = MapDecorator.create();
    this.shadow = new html.DocumentFragment();
    this.style = new html.StyleElement();
    this.precontent = new html.Element.tag('content');
    this.precontent.children.addAll(this.root.children);
    this.options = MapDecorator.useMap(TagUtil.observerDefaults);

    this.$ = QueryShell.create(this.root);
    this.$$ = QueryShell.create(this.shadow);
    this.cssheet = CSS.create();
    this.ink =  SVG.create();

    var id  = Funcs.switchUnless(this.$.attr('id'),guid);
    this._cssId =  [this.tagName,id].join('#');

    this.$.attr('id',id);

    this.style.attributes['type'] = 'text/css';
    this.style.attributes['id'] = Funcs.combineStrings(id,'-style');
    this.style.dataset['tag-name'] = this.tagName;
    this.tagNS = this.$.data("ns");

    var head = this.root.ownerDocument.query('head');
    head.insertBefore(this.style,head.firstChild);

    this.addAtom('myCSS',this.$.style);
    this.addAtom('parentCSS',this.$.parent);

    if(Valids.exist(this.parent)) 
      this.atom('parentCSS').changeHandler(this.$.parent);

    //open dom update and teardown events for public use
    this.addEvent('update');
    this.addEvent('updateCSS');
    this.addEvent('updateDOM');
    this.addEvent('teardownDOM');
    this.addEvent('_updateLive');
    this.addEvent('_teardownLive');

    this.addEvent('domReady');
    this.addEvent('beforedomReady');
    this.addEvent('afterdomReady');

    this.bindWhenDone("beforedomReady",(e){
      this.fireEvent('domReady',e);
    });

    this.bindWhenDone("domReady",(e){
      this.fireEvent('afterdomReady',e);
    });

    this.factories.addFactory('updateDOM',(e){ });
    this.factories.addFactory('teardownDOM',(e){});
    this.factories.addFactory('teardown',(e) => this.root.setInnerHtml(""));

    this.cssheet.f.bind((m){
        this.style.text = m;
    });

    this.shadowfactories.addFactory('update',(e){
          this.fireEvent('teardownDOM',e);
    });

    this.shadowfactories.addFactory('updateCSS',(e){
          this.cssheet.compile();
    });

    this.shadowfactories.addFactory('updateLive',(e){
    });

    this.shadowfactories.addFactory('teardownLive',(e){
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
    
    this.shadow.setInnerHtml(this.precontent.innerHtml);
  }

  void delegateAtoms(){
     this.atomics.onAll((v,k) => k.checkAtomics());
  }

  void init([Function n]){
    var parent = Funcs.switchUnless(this.parent,html.window.document.body);
    var parentOptions = Enums.merge(this.options.core,{'subtree': false});
    this.observer.observe(this.root,
        parent: parent,
        elemOptions: this.options.core,
        parentOptions: parentOptions,
        insert: n);

    this.fireEvent('beforedomReady',true);
  }

  html.Element get parent => this.root.parentNode;

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

  void addEvent(String n,[Function m]){
    this.observer.addEvent(n,m);
  }

  void removeEvent(String n){
    this.observer.removeEvent(n);
  }

  void fireEvent(String n,dynamic a){
    this.observer.fireEvent(n,a);
  }

  void fireFactory(String name,[dynamic n]) => this.factories.fireFactory(name)(n);
  void bindFactory(String name,String ft) => this.factories.bindFactory(name,ft);
  void bindFactoryOnce(String name,String ft) => this.factories.bindFactoryOnce(name,ft);
  void unbindFactory(String name,String ft) => this.factories.unbindFactory(name,ft);
  void unbindFactoryOnce(String name,String ft) => this.factories.unbindFactoryOnce(name,ft);

  void writeFactory(String nf,Function n){
    this.addFactory(nf,n);
    this.createFactoryEvent(nf,nf);
  } 

  void createFactoryEvent(String ev,String n){
      this.addEvent(ev);
      this.bindFactory(ev,n);
  }

  void destroyFactoryEvent(String ev,String n){
    this.unbindFactory(ev,n);
    this.removeEvent(ev);
  }

  void css(Map m) => this.cssheet.ns.sel(this._cssId,m);
  void modCSS(Map m) => this.cssheet.ns.updateSel(this._cssId,m);

  void addAtom(String n,Object b) => this.atomics.add(n,FunctionalAtomic.create(b));
  void removeAtom(String n) => this.atomics.has(n) && this.atomics.destroy(n).destroy();

  FunctionalAtomic atom(String n) => this.atomics.get(n);
  FunctionalAtomic get alphaAtom => this.atom('parentCSS');
  FunctionalAtomic get myAtom => this.atom('myCSS');

  void bindData(String target,Function n,{RegExp reg:null, dynamic val:null}){
      this.bind('attributeChange',(e){
          if(e.detail.attributeName == target){
            var old = e.detail.oldValue,
                nval = this.data(target);
            
            Funcs.when(Valids.match(val,null) && Valids.exist(reg),(){
              if(!reg.hasMatch(nval)) return n(old,nval,e);
            });

            Funcs.when(Valids.exist(val) && Valids.match(reg,null),(){
              if(Valids.match(nval,val)) return n(old,nval,e);
            });

            Funcs.when(Valids.notExist(val) && Valids.notExist(reg),(){
              return n(old,nval,e);
            });

            return null;
          }
      });
  }

  void bindAttr(String target,Function n,{RegExp reg:null, dynamic val:null}){
      this.bind('attributeChange',(e){
          if(e.detail.attributeName == target){
            var old = e.detail.oldValue,
                nval = this.attr(target);
            
            Funcs.when(Valids.match(val,null) && Valids.exist(reg),(){
              if(!reg.hasMatch(nval)) return n(old,nval,e);
            });

            Funcs.when(Valids.exist(val) && Valids.match(reg,null),(){
              if(Valids.match(nval,val)) return n(old,nval,e);
            });

            Funcs.when(Valids.notExist(val) && Valids.notExist(reg),(){
              return n(old,nval,e);
            });

            return null;
          }
      });
  }

  void destroy(){
    this.observer.destroy();
    this.factories.destroy();
    this.sd.clear();
  }

}

class TagUtil{

    static RegExp digitReg = new RegExp(r'\d');
    static RegExp wordReg = new RegExp(r'\w');

    static Map observerDefaults = {
      'subtree': true,
      'childList':true,
      'attributes':true,
      'attributeOldValue': true,
      'characterData': true,
      'characterDataOldValue': true
    };

    static TagRegistry core = TagRegistry.create();
    static Log debug = Log.create(null,null,"TagUtil#({tag}):\n\t{res}\n");
    static CustomValidator defaultValidator = new CustomValidator();

    static num fromPx(String px){
      return num.parse(px
          .replaceAll('px','')
          .replaceAll('%','')
          .replaceAll('em','')
          .replaceAll('vrem','')
          .replaceAll('rem',''));
    }

    static String toPx(num px) => "${px}px";
    static String toPercent(num px) => "${px}%";
    static String toRem(num px) => "${px}rem";
    static String toEm(num px) => "${px}em";

    static void deliverMessage(String sel,String type,dynamic r,[html.Document n]){
      n = Funcs.switchUnless(n,html.window.document);
      TagUtil.queryElem(n,sel,(d){
        TagUtil.dispatchEvent(type,d,r);
      });
    }

    static void deliverMassMessage(String sel,String type,dynamic r,[html.Document n]){
      n = Funcs.switchUnless(n,html.window.document);
      TagUtil.queryAllElem(n,sel,(d){
        d.forEach((v){
          TagUtil.dispatchEvent(type,v,r);
        });
      });
    }

    static void dispatchEvent(html.Element t,String n,[dynamic d]){
      return t.dispatchEvent(new html.CustomEvent(n,detail:d));
    }

    static dynamic getCSS(html.Element n,List a){
      var res = {};
      attr.forEach((f){
         res[f] = n.style.getProperty(f);
      });
      return MapDecorator.create(res);
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

    static void cssElem(html.Element n,Map m){
      m.forEach((k,v){
          var val = v;
          if(Valids.isNumber(v)) val = TagUtil.toPx(v);
          n.style.setProperty(k,val);
      });
    }

    static html.Element createElement(String n){
      TagUtil.defaultValidator.addTag(n);
      return html.window.document.createElement(n);
    }

    static html.Element createHtml(String n){
      return new html.Element.html(n,validator: TagUtil.defaultValidator.rules);
    }

    static html.Element liquify(html.Element n){
      var b = TagUtil.createElement(n.tagName.toLowerCase());
      b.setInnerHtml(n.innerHtml,validator: TagUtil.defaultValidator.rules);
      return b;
    }

    static void deliquify(html.Element l,html.Element hold){
      hold.setInnerHtml(l.innerHtml,validator: TagUtil.defaultValidator.rules);
    }

}


/* end of core code */
