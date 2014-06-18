library atomic;

@MirrorsUsed(targets: const["atomic","mirrorables"])
import 'dart:mirrors';

import 'dart:async';
import 'dart:collection';
import 'package:hub/mirrorables.dart';

 
//here lie the real work loaders,the true atomics

typedef ProtonCallback(Proton n);
typedef ProtonFn(e,Symbol m,Proton n);
typedef NucleusWalker(Object n,dynamic cur,Symbol m,ProtonFn win,[ProtonFn loose]);

class WatchType{
	final String type;
	const WatchType(this.type);
}

abstract class BaseAtom{
	bool get isAtomic => true;
}

abstract class Watchables extends BaseAtom{

	void watchKey(String type) => this.watch(type,Atomic.keyvalue);
	void watchField(String type) => this.watch(type,Atomic.field);

	void watch(String target,WatchType t);
	void unwatch(String target);
	void discardWatches();
	void checkWatches();
	void bind(String m,ProtonCallback n);
	void unbind(String m,ProtonCallback n);
	void bindOnce(String m,ProtonCallback n);
	void unbindOnce(String m,ProtonCallback n);
	void bindExpected(String target,dynamic expected,ProtonCallback n);
	void bindExpectedOnce(String target,dynamic expected,ProtonCallback n);
	void unbindExpected(String target,ProtonCallback n);
	void unbindExpectedOnce(String target,ProtonCallback n);
	void unbindAllExpected();
	void emit(String target,Proton p);
	void destroy();
}


class Proton{
	final dynamic cur,old;
	final String target;
	final Object obj;

	static create(o,t,w,n) => new Proton(o,t,w,n);
	const Proton.special(this.obj,this.target,this.old,this.cur);
	Proton(this.obj,this.target,this.old,this.cur);

	String toString() => "Proton: \n\ttarget:${this.target} old:${this.old} new:${this.cur}";
}

class Nucleus extends Watchables{
	final MapDecorator watchables = MapDecorator.create();
	final MapDecorator voices = MapDecorator.create();
	Object obj;

	Nucleus(this.obj);

	void watch(String target,WatchType type){
		this.watchables.update(target,{
			'target': target,
			'type': type,
			'expected':[]
		});
		this.voices.add(target,new Distributor<Proton>(target));
	}

	void unwatch(String target){
		if(!this.watchables.has(target)) return null;
		this.watchables.destroy(target).clear();
	}

	void destroy(){
		this.discardWatches();
		this.obj = this.watchables = this.voices = null;
	}

	void discardWatches(){
		this.watchables.onAll((e,k) => k.clear());
		this.voices.onAll((e,k) => k.free());
		this.watchables.clear();
		this.voices.clear();
	}

	void hasBind(String target) => this	.watchables.has(target);

	void unbindAllExpected(){
		this.watchables.onAll((n,k){
			k['expected'].forEach((f){
				var psuedo = f['psuedo'], fn = f['fn'];
				this.unbind(n,psuedo);
				this.unbindExpectedOnce(n,psuedo);
			});
		});
	}

	void hasExpected(String target,Function find,Function n,[Function m]){
		if(!this.watchables.has(target)) return null;
		var a = this.watchables.get(target)['expected'];
		return Enums.eachAsync(a,(e,i,o,fn){
			if(e['psuedo'] == find) return fn(e);
			return fn(null);
		},(_,err){
			return (Valids.exist(err) ? n(err) : (Valids.exist(m) && m(null)));
		});
	}

	void bindExpected(String target,dynamic expected,ProtonCallback n){
		if(!this.voices.has(target)) return null;

		var ex = this.watchables.get(target),exp=ex['expected'];

		this.hasExpected(target,n,(e){
			return null;
		},(e){
			var fn = (proton){
				if(Valids.match(target,proton.target)){
					if(Valids.match(proton.cur,expected)) n(proton);
				}
			};
			exp.add({'fn': fn,'psuedo': n,'expected':expected});
			this.bind(target,fn);
		});

	}

	void unbindExpected(String target,ProtonCallback n){
		if(!this.voices.has(target)) return null;

		var ex = this.watchables.get(target),exp=ex['expected'];

		this.hasExpected(target,n,(e){
			this.unbind(target,e['fn']);
		});

	}

	void bindExpectedOnce(String target,dynamic expected,ProtonCallback n){
		if(!this.voices.has(target)) return null;

		var ex = this.watchables.get(target),exp=ex['expected'];

		this.hasExpected(target,n,(e){
			return null;
		},(e){
			var fn = (proton){
				if(Valids.match(target,proton.target)){
					if(Valids.match(proton.cur,expected)) n(proton);
				}
			};
			exp.add({'fn': fn,'psuedo': n,'expected':expected});
			this.bindOnce(target,fn);
		});

	}

	void unbindExpectedOnce(String target,ProtonCallback n){
		if(!this.voices.has(target)) return null;

		var ex = this.watchables.get(target),exp=ex['expected'];

		this.hasExpected(target,n,(e){
			this.unbindOnce(target,e['fn']);
		});

	}

	void bind(String target,ProtonCallback n){
		if(!this.voices.has(target)) return null;
		this.voices.get(target).on(n);
	}

	void unbind(String target,ProtonCallback n){
		if(!this.voices.has(target)) return null;
		this.voices.get(target).off(n);
	}

	void bindOnce(String target,ProtonCallback n){
		if(!this.voices.has(target)) return null;
		this.voices.get(target).once(n);
	}

	void unbindOnce(String target,ProtonCallback n){
		if(!this.voices.has(target)) return null;
		this.voices.get(target).offOnce(n);
	}

	void emit(String target,Proton proton){
		if(!this.voices.has(target)) return null;
		return this.voices.get(target).emit(proton);
	}
} 

class NucleusObject extends Nucleus{
	MapDecorator _hiddenFields;
	classMirror classMirror;
	InstanceMirror instMirror;
	MapDecorator members,declarations;
	SymbolCache cache;
	TaskQueue changes;

	static create(o) => new NucleusObject(o);

	NucleusObject(obj): super(obj){
		this.cache = new SymbolCache();
		this.instMirror = reflect(obj);
		this.classMirror = this.instMirror.type;
		this.members = new MapDecorator.use(this.classMirror.instanceMembers);
		this.declarations = new MapDecorator.use(this.classMirror.declarations);
		this._hiddenFields = MapDecorator.create();
		this.changes = TaskQueue.create(false);
	}

	void queueChanges(String target,Proton q){
		this.changes.queue((){
			return this.emit(target,q);
		});
	}

	void watchField(String n){
		var sm = this.cache.create(n);
		if(this.members.has(sm) || this.declarations.has(sm)){
			this._hiddenFields.update(n,this.instMirror.getField(sm).reflectee);
			super.watchField(n);
		}
	}

	void engine(NucleusWalker walker,[ProtoFn defwin,ProtonFn defloose,Function doneSearch([e])]){
		if(this.watchables.isEmpty) return null;

		var wn = Funcs.switchUnless(defwin,(e,sm,pro) => this.queueChanges(e['target'],pro));

		Enums.eachAsync(this.watchables.core,(e,i,o,fn){
			var sm = this.cache.create(e['target']);
			walker(this.obj,e,sm,wn,defloose);
			fn(null);
		},(_,err){
			this.changes.exec();
			Valids.exist(doneSearch) ? doneSearch(err) : null;
		});
	}

	void handleCollectables(dynamic m,dynamic g,Function n,[Function v,Function j]){
		if((Valids.isList(m) && Valids.isList(g)) || (Valids.isMap(m) && Valids.isMap(g))){
			var diff = Enums.uniqueDiff(m,g);
			if(diff.length > 0) return n(m,g);
			return Valids.exist(v) && v(m,g);
		}
		return Valids.exist(j) && j(m,g);
	}

}

class MapNucleus extends NucleusObject{
	MapDecorator _hidden,_proxy;
	InstanceMirror _hidMirror;

	static create(o) => new MapNucleus(o);

	MapNucleus(Map o): super(o){
		this._hidden = new MapDecorator.unique(this.obj);
		this._proxy = new MapDecorator.use(this.obj);
	}

	void _updateHidden(dynamic key,dynamic val){
		return this._hidden.update(key,Enums.deepClone(val));
	}

	void checkWatches(){
		return this.engine((ob,cur,sm,win,[loose]){
			var target = cur['target'],type = cur['type'];
			// Funcs.when(Valids.match(type,Atomic.method),(){});
			Funcs.when(Valids.match(type,Atomic.field),(){
				if(!this.members.has(sm) && !this.declarations.has(sm)) return null;

				var inst = this.instMirror;
				var hidden = this._hiddenFields;

				var val = inst.getField(sm).reflectee;
				var old = hidden.get(target);

				if(!hidden.has(target)) hidden.update(target,old);

				if(Valids.match(old,val)) 
					return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));

				win(cur,sm,Proton.create(this.obj,target,old,val));
				hidden.update(target,val);

			});
			Funcs.when(Valids.match(type,Atomic.keyvalue),(){

				var proxy = this._proxy;
				var hidden = this._hidden;

				var old = hidden.get(target);
				var val = proxy.get(target);

				if(proxy.has(target) && !hidden.has(target)){
					win(cur,sm,Proton.create(this.obj,target,null,this.proxy.get(target)));
					this._updateHidden(target,val);
					return null;
				}

				if(!proxy.has(target) && this._hidden.has(target)){
					win(cur,sm,Proton.create(this.obj,target,this._hidden.get(target),null));
					this._updateHidden(target,null);
					return null;
				}

				this.handleCollectables(old,val,(o,n){
					win(cur,sm,Proton.create(this.obj,target,old,val));
					this._updateHidden(target,val);
				},(o,n){
					return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));
				},(o,n){
					if(Valids.match(old,val)) 
						return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));
					win(cur,sm,Proton.create(this.obj,target,old,val));
					this._updateHidden(target,val);
				});

				return null;
			});
		});
	}
}

class ListNucleus extends NucleusObject{
	List _hidden;
	InstanceMirror _hidMirror;

	static create(o) => new ListNucleus(o);

	ListNucleus(List o): super(o){
		this._hidden = new List.from(o);
		this._hidMirror = reflect(this._hidden);
	}

	void _updateHidden(dynamic key,dynamic val){
		if(key <= this._hidden.length) return null;
		return this._hidden[key] = Enums.deepClone(val);
	}

	void checkWatches(){
		return this.engine((ob,cur,sm,win,[loose]){
			var target = cur['target'],type = cur['type'];
			// Funcs.when(Valids.match(type,Atomic.method),(){});
			Funcs.when(Valids.match(type,Atomic.field),(){
				if(!this.members.has(sm) && !this.declarations.has(sm)) return null;

				var inst = this.instMirror;
				var hidden = this._hiddenFields;

				var val = inst.getField(sm).reflectee;
				var old = (hidden.has(target) ? hidden.get(target) : _hidMirror.getField(sm).reflectee);
				if(!hidden.has(target)) hidden.update(target,old);

				if(Valids.match(old,val)) 
					return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));

				win(cur,sm,Proton.create(this.obj,target,old,val));
				hidden.update(target,val);

			});
			Funcs.when(Valids.match(type,Atomic.keyvalue),(){
				int nt = int.parse(target);

				if(ob.length <= nt ) return null;

				var old = this._hidden.elementAt(nt);
				var val = ob.elementAt(nt);

				if(Valids.match(old,val)) 
					return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));

				this.handleCollectables(old,val,(o,n){
					win(cur,sm,Proton.create(this.obj,target,old,val));
					this._updateHidden(nt,val);
				},(o,n){
					return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));
				},(o,n){
					if(Valids.match(old,val)) 
						return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));
					win(cur,sm,Proton.create(this.obj,target,old,val));
					this._updateHidden(nt,val);
				});

			});
		});
	}
}

class InstanceNucleus extends NucleusObject{

	static create(o) => new InstanceNucleus(o);

	InstanceNucleus(dynamic n): super(n){
		if(n is Map) throw "please use a MapNucleus for map objects";
		if(n is List) throw "please use a ListNucleus for map objects";
	}

	void watchKey(String n){ return null; }

	void checkWatches(){
		return this.engine((ob,cur,sm,win,[loose]){
			var target = cur['target'],type = cur['type'];
			// Funcs.when(Valids.match(type,Atomic.method),(){});
				Funcs.when(Valids.match(type,Atomic.field),(){
				if(!this.members.has(sm) && !this.declarations.has(sm)) return null;

				var inst = this.instMirror;
				var val = inst.getField(sm).reflectee;
				var hidden = this._hiddenFields;

				if(!hidden.has(target)) return hidden.update(target,val);

				var old = hidden.get(target);

				if(Valids.match(old,val)) 
					return Valids.exist(loose) && loose(this.obj,target,new Proton(this.obj,target,old,val));

				win(cur,sm,Proton.create(this.obj,target,old,val));
				hidden.update(target,val);
			});
		});

	}
}

class Atomic extends BaseAtom{
	 Nucleus n;

	static WatchType keyvalue = const WatchType('MapKV');
	static WatchType field = const WatchType('Field');
	// static WatchType method = const WatchType('method');

	static create(dynamic m) => new Atomic(m);

	Atomic(dynamic m){
		this.n = m is List ? ListNucleus.create(m) : m is Map ? MapNucleus.create(m) : InstanceNucleus.create(m);
	}

	Atomic split(Function spltfn){
		return Atomic.create(spltfn(this.obj));
	}

	dynamic get obj => this.n.obj;

	void watchKey(String type) => this.n.watchKey(type);

	void watchField(String type) => this.n.watchField(type);

	void watch(String target,WatchType t) => this.n.watch(target,t);

	void unwatch(String target) => this.n.unwatch(target);

	void discardWatches() => this.n.discardWatches();

	void checkWatches() => this.n.checkWatches();

	void bind(String m,ProtonCallback n) => this.n.bind(m,n);

	void unbind(String m,ProtonCallback n) => this.n.unbind(m,n);

	void bindOnce(String m,ProtonCallback n) => this.n.bindOnce(m,n);

	void unbindOnce(String m,ProtonCallback n) => this.n.unbindOnce(m,n);

	void bindExpected(String target,dynamic expected,ProtonCallback n) => this.n.bindExpected(target,expected,n);

	void bindExpectedOnce(String target,dynamic expected,ProtonCallback n) => this.n.bindExpected(target,dynamic,n);

	void unbindExpected(String target,ProtonCallback n) => this.n.unbindExpected(target,n);

	void unbindExpectedOnce(String target,ProtonCallback n) => this.n.unbindExpectedOnce(target,n);

	void unbindAllExpected() => this.unbindAllExpected();

	void emit(String target,Proton p) => this.n.emit(target,p);

	void destroy() => this.n.destroy();

}


