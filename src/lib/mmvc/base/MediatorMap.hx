package mmvc.base;

import minject.IInjector;
import mmvc.api.IMediator;
import mmvc.api.IMediatorMap;
import minject.IReflector;
import mcore.data.Dictionary;
import mmvc.api.IViewContainer;
import haxe.Timer;

/**
An abstract <code>IMediatorMap</code> implementation
*/
class MediatorMap extends ViewMapBase, implements IMediatorMap
{
	var mediatorByView:Dictionary<Dynamic, IMediator>;
	var mappingConfigByView:Dictionary<Dynamic, MappingConfig>;
	var mappingConfigByViewClassName:Dictionary<Dynamic, MappingConfig>;
	var mediatorsMarkedForRemoval:Dictionary<Dynamic, Dynamic>;
	var hasMediatorsMarkedForRemoval:Bool;
	var reflector:IReflector;
	
	/**
	Creates a new <code>MediatorMap</code> object
	
	@param contextView The root view node of the context. The map will listen 
	for ADDED_TO_STAGE events on this node
	@param injector An <code>IInjector</code> to use for this context
	@param reflector An <code>IReflector</code> to use for this context
	*/
	public function new(contextView:IViewContainer, injector:IInjector, reflector:IReflector)
	{
		super(contextView, injector);
		this.reflector = reflector;
		
		mediatorByView = new Dictionary(true);
		mappingConfigByView = new Dictionary(true);
		mappingConfigByViewClassName = new Dictionary();
		mediatorsMarkedForRemoval = new Dictionary();
		hasMediatorsMarkedForRemoval = false;
	}
	
	public function mapView(viewClassOrName:Dynamic, mediatorClass:Class<Dynamic>, ?injectViewAs:Dynamic=null, ?autoCreate:Bool=true, ?autoRemove:Bool=true):Void
	{
		#if cpp
		autoCreate = true;
		autoRemove = true;
		#end

		var viewClassName:String = reflector.getFQCN(viewClassOrName);
		
		if (mappingConfigByViewClassName.get(viewClassName) != null)
		{
			throw new ContextError(ContextError.E_MEDIATORMAP_OVR + ' - ' + mediatorClass);
		}
		
		if (reflector.classExtendsOrImplements(mediatorClass, IMediator) == false)
		{
			throw new ContextError(ContextError.E_MEDIATORMAP_NOIMPL + ' - ' + mediatorClass);
		}
		
		var config = new MappingConfig();
		config.mediatorClass = mediatorClass;
		config.autoCreate = autoCreate;
		config.autoRemove = autoRemove;

		if (injectViewAs)
		{
			if (Std.is(injectViewAs, Array))
			{
				config.typedViewClasses = cast(injectViewAs, Array<Dynamic>).copy();
			}
			else if (Std.is(injectViewAs, Class))
			{
				config.typedViewClasses = [injectViewAs];
			}
		}
		else if (Std.is(viewClassOrName, Class))
		{
			config.typedViewClasses = [viewClassOrName];
		}
		mappingConfigByViewClassName.set(viewClassName, config);
		
		if (autoCreate || autoRemove)
		{
			viewListenerCount++;

			if (viewListenerCount == 1)
			{
				addListeners();
			}	
		}
		
		// This was a bad idea - causes unexpected eager instantiation of object graph 
		if (autoCreate && contextView != null && viewClassName == Type.getClassName(Type.getClass(contextView)))
		{
			createMediatorUsing(contextView, viewClassName, config);
		}
	}
	
	public function unmapView(viewClassOrName:Dynamic):Void
	{
		var viewClassName = reflector.getFQCN(viewClassOrName);
		var config = mappingConfigByViewClassName.get(viewClassName);

		if (config != null && (config.autoCreate || config.autoRemove))
		{
			viewListenerCount--;

			if (viewListenerCount == 0)
			{
				removeListeners();
			}
		}

		mappingConfigByViewClassName.delete(viewClassName);
	}
	
	public function createMediator(viewComponent:Dynamic):IMediator
	{
		return createMediatorUsing(viewComponent);
	}
	
	public function registerMediator(viewComponent:Dynamic, mediator:IMediator):Void
	{
		mediatorByView.set(viewComponent, mediator);
		var mapping = mappingConfigByViewClassName.get(Type.getClassName(Type.getClass(viewComponent)));
		mappingConfigByView.set(viewComponent, mapping);
		mediator.setViewComponent(viewComponent);
		mediator.preRegister();
	}
	
	public function removeMediator(mediator:IMediator):IMediator
	{
		if (mediator != null)
		{
			var viewComponent:Dynamic = mediator.getViewComponent();
			mediatorByView.delete(viewComponent);
			mappingConfigByView.delete(viewComponent);
			mediator.preRemove();
			mediator.setViewComponent(null);
		}
		
		return mediator;
	}
	
	public function removeMediatorByView(viewComponent:Dynamic):IMediator
	{
		return removeMediator(retrieveMediator(viewComponent));
	}
	
	public function retrieveMediator(viewComponent:Dynamic):IMediator
	{
		return mediatorByView.get(viewComponent);
	}
	
	public function hasMapping(viewClassOrName:Dynamic):Bool
	{
		var viewClassName:String = reflector.getFQCN(viewClassOrName);
		return mappingConfigByViewClassName.get(viewClassName) != null;
	}
	
	public function hasMediatorForView(viewComponent:Dynamic):Bool
	{
		return mediatorByView.get(viewComponent) != null;
	}
	
	public function hasMediator(mediator:IMediator):Bool
	{
		for (key in mediatorByView)
		{
			if (mediatorByView.get(key) == mediator)
			{
				return true;
			}
		}
			
		return false;
	}
	
	override function addListeners():Void
	{
		if (contextView != null && enabled)
		{
			contextView.viewAdded = onViewAdded;
			contextView.viewRemoved = onViewRemoved;
		}
	}
		
	override function removeListeners():Void
	{
		if (contextView != null)
		{
			contextView.viewAdded = null;
			contextView.viewRemoved = null;
		}
	}
	
	override function onViewAdded(view:Dynamic):Void
	{
		if (mediatorsMarkedForRemoval.get(view) != null)
		{
			mediatorsMarkedForRemoval.delete(view);
			return;
		}
		
		var viewClassName:String = Type.getClassName(Type.getClass(view));
		var config = mappingConfigByViewClassName.get(viewClassName);
		
		if (config != null && config.autoCreate)
		{
			createMediatorUsing(view, viewClassName, config);
		}
	}
	
	override function onViewRemoved(view:Dynamic):Void
	{
		var config = mappingConfigByView.get(view);

		if (config != null && config.autoRemove)
		{
			// don't delay until isAdded works correctly
			removeMediatorByView(view);

			/*
			mediatorsMarkedForRemoval.set(view, view);

			if (!hasMediatorsMarkedForRemoval)
			{
				hasMediatorsMarkedForRemoval = true;
				Timer.delay(removeMediatorLater, 60);
			}
			*/
		}
	}

	function removeMediatorLater():Void
	{
		for (view in mediatorsMarkedForRemoval)
		{
			if (!contextView.isAdded(view))
			{
				removeMediatorByView(view);
			}
			
			mediatorsMarkedForRemoval.delete(view);
		}

		hasMediatorsMarkedForRemoval = false;
	}

	function createMediatorUsing(viewComponent:Dynamic, ?viewClassName:String=null, ?config:MappingConfig=null):IMediator
	{
		var mediator = mediatorByView.get(viewComponent);

		if (mediator == null)
		{
			if (viewClassName == null)
			{
				viewClassName = Type.getClassName(Type.getClass(viewComponent));
			}

			if (config == null)
			{
				config = mappingConfigByViewClassName.get(viewClassName);
			}

			if (config != null)
			{
				for (claxx in config.typedViewClasses) 
				{
					injector.mapValue(claxx, viewComponent);
				}

				mediator = injector.instantiate(config.mediatorClass);

				for (clazz in config.typedViewClasses) 
				{
					injector.unmap(clazz);
				}

				registerMediator(viewComponent, mediator);
			}
		}

		return mediator;			
	}
}

class MappingConfig
{
	public function new(){}

	public var mediatorClass:Class<Dynamic>;
	public var typedViewClasses:Array<Dynamic>;
	public var autoCreate:Bool;
	public var autoRemove:Bool;
}