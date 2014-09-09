library taggables;

import 'dart:collection';
import 'dart:convert';
import 'dart:async';
import 'package:bass/bass.dart';
import 'package:hub/hubclient.dart';
import 'package:dispatch/dispatch.dart';
import 'dart:html' as html;

export 'package:bass/bass.dart';
export 'package:hub/hub.dart';

part 'core.dart';

final Core = TagUtil.core;
final DispatchEvent = (dynamic n,String t,[dynamic msg]){
  if(n is html.Element) return QueryUtil.dispatchEvent(n,t,msg);
  if(n is Tag) return QueryUtil.dispatchEvent(n.root,t,msg);
};
final DeliverMessage = (bool isMass,String sel,String type,dynamic msg,[doc]){
  if(isMass) return QueryUtil.deliverMassMessage(sel,type,msg,doc);
  return QueryUtil.deliverMessage(sel,type,msg,doc);
};
final Bind = (Function fn,[html.Element n,d]){
  n = Funcs.switchUnless(n,html.window.document.body);
  var rg = StoreDispatcher.create(n,d);
  return fn(rg);
};

class StoreDispatcher extends Dispatch{
    final MapDecorator tags = new MapDecorator<String,TagStore>();
    final MapDecorator attrs = new MapDecorator<String,AttrStore>();
    final MapDecorator options = MapDecorator.useMap(TagUtil.observerDefaults);
    final Switch _active = Switch.create();
    html.Element root;
    DisplayHook display;
    ElementObservers observer;
    ElementBindings parentHook;
    bool _attr,_nodes;

    static MapDecorator actions = MapDecorator.useMap({
      'added':0,
      'removed':1,
      'attribute':2,
      'attributeRemoved':3
    });

    static DualBind Bind(String f,TagStore tag,AttrStore attr,[String ns]){
      var binder = DualBind.create((bd){
        attr.adds.off(bd.first);
        attr.removes.off(bd.second);
      },(m){
        var node = m['node'];
        if(Valids.exist(node)){
          if(!node.dataset.containsKey('ns') && Valids.exist(ns)){
              node.dataset['ns'] = ns;
          }
        }

        tag.tagwatch.send({
          'message': f,
          'action': StoreDispatcher.actions.get('added'),
          'node': m['node'],
          'bypass': f,
        });
      },(m){
        tag.tagwatch.send({
          'message': f,
          'action': StoreDispatcher.actions.get('removed'),
          'node': m['node'],
        });
      });

      attr.adds.on(binder.first);
      attr.removes.on(binder.second);

      return binder;
    }

    static create(r,[d,a,n]) => new StoreDispatcher(r,d,a,n);

    StoreDispatcher(this.root,[DistributedObserver d,bool attr,bool nodes]): super(){
      this._active.switchOn();
      this.display = DisplayHook.create(html.window);
      this.observer = ElementObservers.create(Valids.exist(d) ? d : DistributedObserver.create());
      this.parentHook = ElementBindings.create();
      this._attr = Funcs.switchUnless(attr,true);
      this._nodes = Funcs.switchUnless(nodes,true);
      
      if(!!this._attr){
        this.observer.bind('attributeChange',(e){
            if(e.detail.target is! html.Element) return null;
            var name = e.detail.target.tagName.toLowerCase();
            var data = ({
              'message':e.detail.attributeName,
              'action': StoreDispatcher.actions.get('attribute'),
              'node': e.detail.target,
              'record': e.detail,
              'tag': name,
            });
            this.dispatch(data);
        });

        this.observer.bind('attributeRemoved',(e){
            if(e.detail.target is! html.Element) return null;
            var name = e.detail.target.tagName.toLowerCase();
            var data = ({
              'message':e.detail.attributeName,
              'action': StoreDispatcher.actions.get('attributeRemoved'),
              'node': e.detail.target,
              'record': e.detail,
              'tag': name,
            });
            this.dispatch(data);
        });
      }

      if(!!this._nodes){
        this.observer.bind('childAdded',(e){
          var nodes = e.detail.addedNodes;
          nodes.forEach((f){
            if(f is! html.Element) return null;
            var name = f.tagName;
            this.dispatch({
              'message':name,
              'action': StoreDispatcher.actions.get('added'),
              'node': f,
            });
          });
        });

        this.observer.bind('childRemoved',(e){
          var nodes = e.detail.removedNodes;
          nodes.forEach((f){
            if(f is! html.Element) return null;
            var name = f.tagName;
            this.dispatch({
              'message':name,
              'action': StoreDispatcher.actions.get('removed'),
              'node': f,
            });
          });
        });
      }

      this.parentHook.bind('unload',(e){
        this.disable();
      });

      this.observer.bind('unload',(e){
        if(e.target == this.root){
          this.disable();
        }
      });

    }

    bool get isActive => this._active.on();

    void init(){
      this.observer.observe(this.root,this.options.core);
      if(Valids.exist(this.root.parent)) this.parentHook.bindTo(this.root.parent);
      this.enable();
    }

    void disable(){
      this.display.stop();
      this.observer.fireEvent('domRemoved',e);
    }

    void enable(){
      this.observer.fireEvent('domAdded',this.root);
      this.display.run();
    }

    void destroy(){
      this.root = null;
      this.display.stop();
      this.observer.destroy();
      this.parentHook.destroy();
      super.destroy();
      this._active.switchOff();
    }

    dynamic get bind => this.observer.bind;
    dynamic get bindOnce => this.observer.bindOnce;
    dynamic get unbind => this.observer.unbind;
    dynamic get unbindOnce => this.observer.unbindOnce;
    dynamic get bindWhenDone => this.observer.bindWhenDone;
    dynamic get unbindWhenDone => this.observer.unbindWhenDone;
    dynamic get addEvent => this.observer.addEvent;
    dynamic get removeEvent => this.observer.removeEvent;
    dynamic get fireEvent => this.observer.fireEvent;
    dynamic get events => this.observer.getEvent;

    TagStore tagStore(String tg){
      if(!this.isActive) return null;
      if(this.tags.has(tg)) return this.stores.get(tg);
      var store = TagStore.create(tg,this);
      this.tags.add(tg,store);
      return store;
    }

    AttrStore attrStore(String tg){
      if(!this.isActive) return null;
      if(this.attrs.has(tg)) return this.attrs.get(tg);
      var attr = AttrStore.create(tg,this);
      this.attrs.add(tg,attr);
      return attr;
    }
}

class TagHouse extends StoreHouse{

  static create(s) => new TagHouse(s);
  TagHouse(TagStore store): super(store);

  Future<Tag> delegateAdd(html.Element tag,[String bypass]){
    var taghash = tag.hashCode.toString();
    if(this.storehouse.has(taghash)) return new Future.value(this.storehouse.get(taghash));
    var comp = new Completer(),
        name = Valids.exist(bypass) ? bypass : tag.tagName.toLowerCase(),
        ns = tag.dataset['ns'];

    this.store.registry.delegateSearch(name,ns).then((ns){
        var tagob = ns.createTag(tag,name);
        if(Valids.exist(tagob)) return comp.complete(tagob);
        return comp.completeError(new Exception("Tag Not Found!"));
    },onError:comp.completeError);

    return comp.future.then((t){
        this.storehouse.add(taghash,t);
        return t;
    });
  }

  Future<Tag> delegateRemove(html.Element tag){
    var taghash = tag.hashCode.toString();
    if(!this.storehouse.has(taghash)) return new Future.error(new Exception('Not Found'));
    return new Future.value(this.storehouse.destroy(taghash));
  }

  bool hasTag(html.Element tag){
    var taghash = tag.hashCode.toString();
    return this.storehouse.has(taghash);
  }

}

class AttrHouse extends StoreHouse{


  static create(s) => new AttrHouse(s);
  AttrHouse(AttrStore store): super(store);

  Future<Tag> delegateAdd(html.Element tag){
    var taghash = tag.hashCode.toString();
    if(this.storehouse.has(taghash)) return new Future.error('Already Added!');
    return new Future((){
        this.storehouse.add(taghash,tag);
        return tag;
    });
  }

  Future<Tag> delegateRemove(html.Element tag){
    var taghash = tag.hashCode.toString();
    if(!this.storehouse.has(taghash)) return new Future.error(new Exception('Not Found!'));
    return new Future.value(this.storehouse.destroy(taghash));
  }

  bool hasTag(html.Element tag){
    var taghash = tag.hashCode.toString();
    return this.storehouse.has(taghash);
  }

}

class AttrStore extends SingleStore{
  String selector;
  DispatchWatcher tagwatch;
  AttrHouse house;
  Distributor adds,removes;

  static create(ts,d) => new AttrStore(ts,d);

  AttrStore(String selector,StoreDispatcher dp): super(dp){
    this.selector = selector;
    this.house = AttrHouse.create(this);
    this.adds = Distributor.create('attr-adds');
    this.removes = Distributor.create('attr-removes');
    this.tagwatch = dp.watch((m){
      var message = m['message'],node = m['node'];
      if(Valids.match(message,selector) || 
        node.attributes.containsKey(selector) || 
        this.house.hasTag(node)) return true;
      return false;
    });

    this.tagwatch.listen(this.delegateRequest);
    //tell them to send to us all related tags
     var types = this.dispatch.root.querySelectorAll(this.selector);
     types.forEach((f){
      this.tagwatch.send({
        'message':this.selector,
        'action': StoreDispatcher.actions.get('attribute'),
        'node': f,
        'record':null,
        'tag':f.tagName.toLowerCase()
      });
     });
  }

  void delegate(Map v){ return null; }

  void delegateRequest(m){
      var addbit = StoreDispatcher.actions.get('added');
      var rmbit = StoreDispatcher.actions.get('removed');
      var attr = StoreDispatcher.actions.get('attribute');
      var attrrm = StoreDispatcher.actions.get('attributeRemoved');

      var action = m['action'],node = m['node'],attrs = node.attributes;

      if(action == attr || (action == addbit && (node.matches(this.selector) || attrs.containsKey(this.selector)))){
        this.house.delegateAdd(m['node'])
        .then((n){
          this.adds.emit(m);
        })
        .catchError((e){});
      }

      if(action == rmbit || action == attrrm){

        if(action == attrrm){
         if(attrs.containsKey(this.selector)) return null;
         if(node.matches(this.selector)) return null;
        }

        if(action == rmbit){
          if(!attrs.containsKey(this.selector) && !node.matches(this.selector)) return null;
        }

        this.house.delegateRemove(m['node'])
        .then((n){
            this.removes.emit(m);
        })
        .catchError((e){});
      };

  }

}

class TagStore extends SingleStore{
  String tagName;
  TagRegistry registry;
  DispatchWatcher tagwatch;
  TagHouse house;

  static create(ts,d,[t]) => new TagStore(ts,d,t);

  TagStore(String tagName,StoreDispatcher dp,[TagRegistry t]): super(dp), tagwatch = dp.watch(tagName){
    this.tagName  = tagName.toLowerCase();
    this.registry = Funcs.switchUnless(t,TagUtil.core);
    this.house = TagHouse.create(this);

    this.tagwatch.listen(this.delegateRequest);
    //tell them to send to us all related tags
     var types = this.dispatch.root.querySelectorAll(this.tagName);
     types.forEach((f){
      this.tagwatch.send({
        'message':this.tagName,
        'action': StoreDispatcher.actions.get('added'),
        'node': f,
      });
     });
  }

  void delegate(Map v){ return null; }

  void delegateRequest(m){
      var addbit = StoreDispatcher.actions.get('added');
      var rmbit = StoreDispatcher.actions.get('removed');

      if(m['action'] == addbit){
        this.house.delegateAdd(m['node'],m['bypass'])
        .then((f){
          f.delegateAtoms(this.dispatch.display);
        })
        .catchError((e){});
      }

      if(m['action'] == rmbit){
        this.house.delegateRemove(m['node'])
        .then((f){
          f.destroy();
        })
        .catchError((e){});
      }
  }
}

class Tag extends DualObservers{
  final String guid = Hub.randomString(4).replaceAll(QueryUtil.digitReg,'').replaceAll('-','');
  final String tagName;
  String tagNS; String _cssId;
  bool _active = true;
  html.Element root;
  Completer<Timer> _atomtimer;
  html.DocumentFragment shadow;
  html.StyleElement style;
  html.Element precontent;
  EventsFactory factories,shadowfactories;
  MapDecorator atomics,sd,options;
  QueryShell $,$$;
  CSS cssheet;
  SVG ink;
  int ms = 300;

  static create(r,[ns,dr]) => new Tag(r,ns,dr);

  Tag(html.Element root,[this.tagNS,DistributedObserver dist]): this.root = root,this.tagName = root.tagName.toLowerCase(), super(dist,null){
    this._atomtimer = new Completer();
    QueryUtil.defaultValidator.addTag(this.tagName);
    this.factories = EventsFactory.create(this);
    this.shadowfactories = EventsFactory.create(this);
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

    if(!this.$.hasAttr('id')) this.$.attr('id',id);
    this.tagNS = this.$.data("ns");

    this.style.attributes['type'] = 'text/css';
    this.style.attributes['id'] = Funcs.combineStrings(id,'-style');
    this.style.dataset['tag-name'] = this.tagName;


    var head = this.root.ownerDocument.query('head');
    head.insertBefore(this.style,head.firstChild);

    this.addAtom('myCSS',this.$.style);
    if(Valids.exist(this.parent))
        this.addAtom('parentCSS',this.$.parent.style);
    else this.addAtom('parentCSS',null);


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
    
    this.bind('domReady',(e){
      if(Valids.exist(this.parent)) 
        this.atom('parentCSS').changeHandler(this.$.parent.style);
    });

    this.shadow.setInnerHtml(this.precontent.innerHtml);
  }

  void delegateAtoms(DisplayHook hk){
    if(!this._active) return null;
    if(this.atomtimer.isCompleted) return null;
     this.atomtimer.complete(hk.scheduleEvery(this.ms,([ms]){
       this.atomics.onAll((v,k) => k.checkAtomics());
     }));
  }

  void init([Function n,html.Element p]){
    var parent = Funcs.switchUnless(p,Funcs.switchUnless(this.parent,html.window.document.body));
    var parentOptions = Enums.merge(this.options.core,{'subtree': false});
    this.observeRoot(this.options.core);
    this.observeParent(parent,parentOptions,n);
    if(Valids.exist(this.parent)) 
      this.atom('parentCSS').changeHandler(this.$.parent.style);
    this.fireEvent('beforedomReady',true);
  }

  html.Element get parent => this.root.parentNode;

  void addFactory(String name,Function n(e)) => this.factories.addFactory(name,n);
  Function updateFactory(String name,Function n(e)) => this.factories.updateFactory(name,n);
  Function getFactory(String name) => this.factories.getFactory(name);
  bool hasFactory(String name) => this.factories.hasFactory(name);

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
  FunctionalAtomic get parentAtom => this.atom('parentCSS');
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

  Future get atomTimer => this._atomtimer.future;

  void destroy(){
    this._active = false;
    this.atomics.onAll((v,k) => k.destroy());
    this.atomTimer.then((t) => t.cancel());
    this.sd.clear();
    this.options.clear();
    this.shadow.remove();
    this.style.remove();
    this.precontent.remove();
    this.observer.destroy();
    this.factories.destroy();
    this.shadowfactories.destroy();
    this.cssheet.destroy();
    this.ink.destroy();
    this.$.destroy();
    this.$$.destroy();
    this.root = this.cssheet = this.ink = null;
  }

}

class TagUtil{

    static RegExp digitReg = new RegExp(r'\d');
    static RegExp wordReg = new RegExp(r'\w');
    static TagRegistry core = TagRegistry.create();
    static Map observerDefaults = {
      'subtree': true,
      'childList':true,
      'attributes':true,
      'attributeOldValue': true,
      'characterData': true,
      'characterDataOldValue': true
    };

}


/* end of core code */
