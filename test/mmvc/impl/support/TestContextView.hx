/*
Copyright (c) 2012 Massive Interactive

Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
of the Software, and to permit persons to whom the Software is furnished to do 
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
*/

package mmvc.impl.support;
	
import mcore.data.Dictionary;
import mmvc.api.IViewContainer;

class TestContextView implements IViewContainer
{
	var views:Dictionary<Dynamic, Bool>;

	public var viewAdded:Dynamic -> Void;
	public var viewRemoved:Dynamic -> Void;

	@inject("injectionName")
	public var injectionPoint:String;
	
	public function new()
	{
		views = new Dictionary<Dynamic, Bool>();
	}

	public function addView(view:Dynamic)
	{
		views.set(view, true);

		if (viewAdded != null)
		{
			viewAdded(view);
		}
	}

	public function removeView(view:Dynamic)
	{
		views.delete(view);

		if (viewRemoved != null)
		{
			viewRemoved(view);
		}
	}

	public function isAdded(view:Dynamic)
	{
		return views.exists(view);
	}
}