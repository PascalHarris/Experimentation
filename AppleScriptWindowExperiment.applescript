use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property theWindow : missing value
property theLabel : missing value
property counter : 0
property maxCount : 10
property theTimer : missing value

-- Main entry point. Schedules window creation on the main thread.
on run
	-- Schedule createWindow to run on the main thread
	my performSelectorOnMainThread:"createWindow" withObject:(missing value) waitUntilDone:true
	
	-- Run the event loop to process timer events and window updates
	set endDate to current application's NSDate's dateWithTimeIntervalSinceNow:15
	current application's NSRunLoop's mainRunLoop()'s runUntilDate:endDate
end run

-- Creates the window and starts a repeating timer for updates.
-- Called on main thread via performSelectorOnMainThread.
-- Modifies: theWindow, theLabel, theTimer
on createWindow()
	current application's NSApplication's sharedApplication()'s activateIgnoringOtherApps:true
	
	set theWindow to current application's NSWindow's alloc()'s initWithContentRect:{{100, 100}, {400, 100}} styleMask:7 backing:2 defer:false
	theWindow's setTitle:"Live Status"
	theWindow's setLevel:(current application's NSFloatingWindowLevel)
	
	set theLabel to current application's NSTextField's alloc()'s initWithFrame:{{20, 30}, {360, 40}}
	theLabel's setStringValue:"Starting..."
	theLabel's setBezeled:false
	theLabel's setDrawsBackground:false
	theLabel's setEditable:false
	theLabel's setSelectable:false
	theLabel's setFont:(current application's NSFont's systemFontOfSize:18)
	
	theWindow's contentView()'s addSubview:theLabel
	theWindow's makeKeyAndOrderFront:me
	
	-- Create a repeating timer that fires every 1 second
	set theTimer to current application's NSTimer's scheduledTimerWithTimeInterval:1 target:me selector:"updateFromTimer:" userInfo:(missing value) repeats:true
end createWindow

-- Timer callback. Updates the label and stops after maxCount iterations.
-- Parameter: sender Ñ the NSTimer that fired (unused but required by selector signature)
on updateFromTimer:sender
	set counter to counter + 1
	theLabel's setStringValue:("Count: " & counter )
	theWindow's display()
	
	if counter ³ maxCount then
		theTimer's invalidate()
		theWindow's orderOut:me
	end if
end updateFromTimer: