library taggables;

import 'dart:collection';
import 'dart:convert';
import 'dart:async';
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
final Bind = (Function fn,[html.Element n,d]){
  n = Funcs.switchUnless(n,html.window.document.body);
  var rg = TagDispatcher.create(n,d);
  return fn(rg);
};

class TagDispatcher extends Dispatch{
    final MapDecorator stores = new MapDecorator<String,TagStore>();
    final MapDecorator options = MapDecorator.useMap(TagUtil.observerDefaults);
    html.Element root;
    DisplayHook display;
    ElementObservers observer;
    ElementHooks parentHook;

    static MapDecorator actions = MapDecorator.useMap({
      'added':0,
      'removed':1,
      'attribute':2
    });

    static create(r,[d]) => new TagDispatcher(r,d);

    TagDispatcher(this.root,[DistributedObserver d]): super(){
      this.display = DisplayHook.create(html.window);
      this.observer = ElementObservers.create(Valids.exist(d) ? d : DistributedObserver.create());
      this.parentHook = ElementHooks.create();

      this.observer.bind('attributeChange',(e){
          var name = this.root.tagName.toLowerCase();
          var data = ({
            'message':name,
            'action': TagDispatcher.actions.get('attribute'),
            'node': this.root,
            'record': e.detail,
            'attr':e.detail.attributeName
          });
          this.dispatch(data);
      });

      this.observer.bind('attributeRemoved',(e){
          var name = this.root.tagName.toLowerCase();
          var data = ({
            'message':name,
            'action': TagDispatcher.actions.get('attribute'),
            'node': this.root,
            'record': e.detail,
            'attr':e.detail.attributeName
          });
          this.dispatch(data);
      });

      this.observer.bind('childAdded',(e){
        var nodes = e.detail.addedNodes;
        nodes.forEach((f){
          if(f is! html.Element) return null;
          var name = f.tagName;
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
          if(f is! html.Element) return null;
          var name = f.tagName;
          this.dispatch({
            'message':name,
            'action': TagDispatcher.actions.get('removed'),
            'node': f,
          });
        });
      });

      this.parentHook.bind('unload',(e){
        this.disable();
      });

      this.observer.bind('unload',(e){
        if(e.target == this.root){
          this.disable();
        }
      });

    }

    void init(){
      this.observer.observe(this.root,this.options.core);
      if(Valids.exist(this.root.parent)) this.parentHook.bindTo(this.root.parent);
      this.enable();
    }

    TagStore createStore(String tg){
      if(this.stores.has(tg)) return this.stores.get(tg);
      var store = TagStore.create(tg,this);
      this.stores.add(tg,store);
      return store;
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

}

class TagHouse extends StoreHouse{

  static create(s) => new TagHouse(s);
  TagHouse(TagStore store): super(store);

  Future<Tag> delegateAdd(html.Element tag){
    var taghash = tag.hashCode.toString();
    if(this.storehouse.has(taghash)) return new Future.value(this.storehouse.get(taghash));
    var comp = new Completer(),
        name = tag.tagName.toLowerCase(),
        ns = tag.dataset['ns'];

    this.store.registry.delegateSearch(name,ns).then((ns){
        var tagob = ns.createTag(tag);
        if(Valids.exist(tagob)) return comp.complete(tagob);
        return comp.completeError(new Exception("Tag Not Found!"));
    },onError:comp.completeError);

    return comp.future.then((t){
        this.storehouse.add(taghash,t);
    });
  }

  Future<Tag> delegateRemove(){
    var taghash = tag.hashCode.toString();
    if(!this.storehouse.has(taghash)) return new Future.error(new Exception('Not Found'));
    return new Future.value(this.storehouse.destroy(taghash));
  }

}

class TagStore extends SingleStore{
  String tagName;
  TagRegistry registry;
  DispatchWatcher tagwatch;
  StoreHouse house;

  static create(ts,d,[t]) => new TagStore(ts,d,t);

  TagStore(String tagName,TagDispatcher dp,[TagRegistry t]): super(dp), tagwatch = dp.watch(tagName){
    this.tagName  = tagName.toLowerCase();
    t = Funcs.switchUnless(t,TagUtil.core);
    this.registry = t;
    this.house = TagHouse.create(this);
    this.tagwatch = this.dispatch.watch(tagName);

    this.tagwatch.listen(this.delegateRequest);
    //tell them to send to us all related tags
     var types = this.dispatch.root.querySelectorAll(this.tagName);
     types.forEach((f){
      this.tagwatch.send({
        'message':this.tagName,
        'action': TagDispatcher.actions.get('added'),
        'node': f,
      });
     });
  }

  void delegate(Map v){ return null; }

  void delegateRequest(m){
      var addbit = TagDispatcher.actions.get('added');
      var rmbit = TagDispatcher.actions.get('removed');

      if(m['action'] == addbit){
        this.house.delegateAdd(m['node'])
        .then((f){
          f.delegateAtoms(this.house.dispatch.display);
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
  final String guid = Hub.randomString(4).replaceAll(TagUtil.digitReg,'').replaceAll('-','');
  final String tagName;
  String tagNS;
  String _cssId;
  final html.Element root;
  Timer atomtimer;
  html.DocumentFragment shadow;
  html.StyleElement style;
  html.Element precontent;
  EventFactory factories,shadowfactories;
  MapDecorator atomics,sd,options;
  QueryShell $,$$;
  CSS cssheet;
  SVG ink;
  int ms = 300;

  static create(r,[ns,dr]) => new Tag(r,ns,dr);

  Tag(html.Element root,[this.tagNS,DistributedObserver dist]): this.root = root,this.tagName = root.tagName.toLowerCase(), super(dist,null){
    TagUtil.defaultValidator.addTag(this.tagName);
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
    this.tagNS = this.$.data("ns");

    this.style.attributes['type'] = 'text/css';
    this.style.attributes['id'] = Funcs.combineStrings(id,'-style');
    this.style.dataset['tag-name'] = this.tagName;


    var head = this.root.ownerDocument.query('head');
    head.insertBefore(this.style,head.firstChild);

    this.addAtom('myCSS',this.$.style);
    this.addAtom('parentCSS',this.$.parent.style);

    if(Valids.exist(this.parent)) 
      this.atom('parentCSS').changeHandler(this.$.parent.style);

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

  void delegateAtoms(DisplayHook hk){
     this.atomtimer = hk.scheduleEvery(([ms]){
       this.atomics.onAll((v,k) => k.checkAtomics());
     });
  }

  void init([Function n,html.Element p]){
    var parent = Funcs.switchUnless(p,Funcs.switchUnless(this.parent,html.window.document.body));
    var parentOptions = Enums.merge(this.options.core,{'subtree': false});
    this.observeRoot(this.options.core);
    this.observeParent(parent,parentOptions,n);
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

  void destroy(){
    if(Valids.exist(this.atomtimer)) this.atomtimer.cancel();
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
