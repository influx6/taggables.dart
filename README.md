# Taggables

##Description:
		A simple framework built around decoupling of html tags and functionality whilst still providing the same flexibility that comes with the xtag approach,although due to limitations in dart:html
		build approach certain differences occur especially when it comes to html sanitizations.

##Examples:

- Code from test/spec.dart
```		
	/*
	  All custom tags start as registered functions which mutate the operations
	  of the tags as necessary,the shadowDOM is not used but two 
	  documentfragment are,were one acts as the live feed and the other the shadow 
	  and are automatically synced when an updateDOM event is fired,with each other 
	  by copying content from shadow to live document fragment but a switch to 
	  shadowDOM will be possible by use of extension functions.
	  
	  Thanks to Bass as a preprocessor,styles can be included and updated as 
	  desired using the bass api but the styles are simple added to the head tag as 
	  style tags of the current document which doesnt conflict with any lower 
	  document style below since if those over-write a style it precedes it and 
	  hence no-conflicts, so it would be adviced to as is generally scope your tags 
	  careful as is the norm.
	  
	  Simply register a new tag mutator with the core and either include that tag 
	  in the document which the Core will automatically peek up or later as you 
	  wish,the core watches its root(generally the body tag) and once its find 
	  any registerd tags it will initialize according.
	  
	  A few Gotchas:
	   Due to dart:html html sanitization, generally custom tags are filtered if 
	   your are using innerHtml,workarounds and gotchas includes:
	   
	   1. Always using Taggables static createElement and createHtml as the wrapp
	   and bind in a custom validator into the innerhtml calls and register any 
	   custom tag which are not registered as taggales by using the:
	      ``` Taggables.defaultValidator.addTag('new_tag'); ```
	   function call,when the createElement and createHtml is called these tags 
	   wont be stripped
	   
	   2. Never put a tag within itself from within a tag definition,
	   because it creates an endless loop of tag initiziations (i.e including a call 
	   in the 'beforedom','domready' or 'afterdom' event that adds a tag into 
	   itself(adding a dashboard tag into itself from these events, bad idea) but 
	   feel free to do so directly from the dom (i.e within your markup),
	   it won't cause any loop, these occurs because each new tag will initialize is 
	   own copy since its part of its buildup state and so on, so really bad idea to 
	   do this within any of those events but it can be included as part of a tags 
	   content and no loops will occur.
	   
	   3. If a tag contains already placed content,these content are immediately
	   copied into the shadow document fragment and will always be copied back when
	   the updateDOM event is fired,it allows internal change of values without 
	   creating massive level of updateDOM firing on every change and allows you 
	   to provide default tags or content for your tags,for example if you have a
	   Timeline tag which has/expects TimeEvent tag content,you can include these 
	   within the dom markup for your timeline tag,it will be copied over into your 
	   shadow document fragment then you can update them and simply call 
	   updateDOM when all changes have finished occuring within the shadow document 
	   fragment,it reduces and ensures effective behaviour.
	   
	   Beyond these Taggables is a breeze to work with and extend as much as desired,
	   hopefully there will be a better approach to dom validation as the current 
	   implementation forces abit of hoops and jumps,maybe include a global 
	   validator used by default that can be accessed from the window object,
	   which can effective reduces all the custom builders that generally must be 
	   include in every setInnerHtml calls but can especailly when its not code you 
	   can control or modify but its up to the dart core team. 
	   Enjoy and cheers.
	*/
	Taggables.core.register('dashboards','dashboard-header',(tag,init){

		tag.css.sel('dashboard-header',{
			'display':'block',
			'background': 'rgba(0,0,0,0.7)',
			'overflow': 'hidden',
			'width':'200px',
			'height': '30px',
			'padding': "0px 0px 0px 10px",
			'box-sizing':'border-box',
			'-moz-box-sizing':'border-box',
			'-webkit-box-sizing':'border-box',
			'& span':{
				'display':'block',
				'width':'90%',
				'height':'100%',
				'color': 'rgba(255,255,255,1)',
				'font-size': '1.5em',
				'font-style': 'uppercase'
			}
		});

		tag.bind('beforedomReady',(e){
			tag.createElement("span",tag.data('title'));
		});

		tag.addFactory('titleUpdate',(e){
			tag.query('span',(s){
				tag.fetchData('title',(d){
					s.setInnerHtml(d);
				});
				tag.fireEvent('updateDOM',true);
			});
		});

		tag.bindFactory('attributeChange','titleUpdate');

		init();
	});

	//creates a hook and automatically binds to the body tag
	Hook.bindWith(null,null,(doc,init){
		init(); //initalizes it lazy style
	});

```

  - Code from web/index.html:
```

	<!DOCTYPE html>
		<html>
			<head>
				<meta charset="utf-8">
				<title>Taggables</title>
				<link rel="stylesheet" href="./assets/css/reset.css"/>
				<link rel="stylesheet" href="./assets/css/grid.css"/>
				<link rel="stylesheet" href="./assets/css/helpers.css"/>
				<link rel="stylesheet" href="./assets/css/spark.css"/>
				<meta lang='en' />
				<style type="text/css"></style>
			</head>
			<body>
				<dashboard-header data-title="suckerbox"></dashboard-header>
			</body>
			<script src="spec.dart" type="application/dart"></script>
			<script src="packages/browser/dart.js"></script>
	</html>

```
