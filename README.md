# Taggables

##Description:
  Taggables is a lightweight combination of techniques pickup from the best web components around like angular.dart,
  mozilla xtag and a few from polymer and even methodological approaches from behaviours custom dart library. Its has a lighter,more direct approach to web components in that it brings in the functionality of codable tag types and attribute driven extensions, i.e it allows one to choose to either create custom tags or apply custom behaviour to normal tags which provides a powerful but lightweight alternative. It does not come with the ringbells of templates and two-way bindings,it simply allows you to create and extend tags with behaviours that with ease without much overhead to using transformers to get a compiled version of the available files.Taggables is just another approach not a slap in the face to the other awesome approach out there.


##Examples:

  ###Registries: 
	Taggables uses internal registries to hold functions that alter the behaviours of html.Elements,it allows a nice structure for the behaviour effectors and also these registry ensure namespacing to allow different tag defintions of similar name to exist. Taggables provide a single global-space registry 'Core' where all tag definitions should be registered into.

	  ```		

	      //lets register a new tag type under the 'atoms' namespace
	      Core.register('atoms','atom',(t){
		t.css({
		  'background': 'red',
		  'width':'100%',
		  'height':'100%'
		});

		//initialize the tag 
		t.init();
	      });

	  ```		

  ###StoreDispatchers:
	 At the heart of taggables is the dispatchers using mutation observers hence allowing natual observations of dom changes be it node removals/additions or attribute changes, the dispatcher employs the flux pattern and simply propagates all changes to all who will listen and custom watchers can be created that listen for specific types of changes tagged by message id's.

	  ```		

	      var doc = window.document;
	      var dh =  doc.querySelector('#dh');

	      var watch = StoreDispatcher.create(doc.body);
	      var all = watch.watch((f) => true); // will report all messages
	      var div = watch.watch('div'); // report only when message id's have the value 'div'

	  ```		

  ###Watchers and Stores
	Watchers provide a suitable means of listening into dispatchers for specific messages,it can be passed a string, regexp or function to validate the type of messages to accept,any watcher can send messages into it's dispatcher. Stores are the approach to allow custom type behaviours with dispatchers,generally they don't really have a concrete definition as it depends on what you desire them to do but think of them as models in a MVC pattern. Taggables provides two major store types:
	- AttrStore: a attribute store allows us to watch and store tags that meet specific attribute selectors
	- TagStore: a tag store allows the underline handling for custom tags according to those in the registry,ensuring proper lifecycle

	  ```		

	      -> We create a tagstore to watch custom html.Element tag 'atom', and callup the corresponding definition in the tag registry

	      var store = watch.tagStore('atom');

	      -> We can also watch for attributes that are added or removed on tags but even better,the 
	      attribute value supplied here can be any valid css attribute selector has underneath
	      it uses the html.Elements.matches to check the nodes if they match or if the attribute
	      exists on the html.Element

	      var attr = watch.attrStore('atomify');

	      -> Listen into the html.Element being added into this attribute store,that is does that match the attribute selector

	      attr.adds.on(Funcs.tag('attr-added to'));

	      -> Listen to the html.Element being removed from these store has they no longer meet the attribute selector criteria

	      attr.removes.on(Funcs.tag('attr-removed to'));

	  ```		


   ###Binding:
	We can wire up a tagstore and attrstore,what these means is we can create a angular type directives where certain attributes can be immediately on addition to a html.Element custom or inbuilt tag, be immediately effected by a custom tag definition and provides a powerful approach as these means instead of creating custom tag types we can equally upgrade existing current ones, and as the tag definition don't restrict the type of operation we can have a Core registry for a tag type that necessary only addeds extra functionality to a tag rather than building up a new one.

	  ```		
	      -> Watch the store and attr store instances and when a attr is added apply the atom definition on the html.Element

	      var wire = StoreDispatcher.Bind('atom',store,attr);

	  ```		

  ###Startup:
	To get things running simply call the dispatcher.init method,which starts up watching the dom and adding existing tags stores or attribute stores to get all html.Element tags that meet their criterias.

	  ```		
	      
	      watch.bind('domAdded',Funcs.tag('watch-domAdded'));
	      watch.bind('childAdded',Funcs.tag('cdadd'));

	      watch.init();


	  ```
