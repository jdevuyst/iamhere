# I Am Here (Don’t Sleep)

I Am Here is a small app that sits in the right side of your menu bar. Its single purpose is to prevent your screen from going into standby when you don't want it to.

![Screenshot](https://jdevuyst.appspot.com/apps/2014/iamhere/screenshot.jpg)

I Am Here predicts when your screen is about to sleep. It activates the webcam moments before your screen goes blank. If it detects that someone is sitting in front of the computer then the screen will stay on. I Am Here uses face detection to determine whether someone is sitting in front of the computer.

You can also instruct I Am Here to postpone standby by a number of minutes or hours, or to never let your computer sleep.

## Known Issues

I Am Here is fairly battery hungry when face detection is turned on. This is particularly the case for laptops with discrete GPUs. Moreover, I Am Here is somewhat less reliable than some of the (non-gratis) alternatives in the App Store. The APIs for preventing the display from sleeping are not documented well, and at some point I found that I Am Here was working ‘well enough’ for my own purposes so I stopped trying to make it more reliable.

I wrote I Am Here as one of my first Objective-C projects in the first half of 2014. It originally targetted OS X Mountain Lion. Rudimentary testing suggests it still works in OS X Yosemite. YMMV. :)

## The Good Parts

Regardless of the above caveats, the source code is definitely not all bad. It’s written in a defensive style that has proven to be pretty robust. Moreover, the code covers a nice mix of OS X programming aspects in a relatively small body of code—viz. it’s a menu bar app, it can add itself to the list of apps to run when the user logs in, it does face detection, and it does some low-level power management voodoo.

## Download

If you’re interested in running the app, rather than looking at the source code, you will want to download the DMG [here](https://jdevuyst.appspot.com/apps/2014/iamhere/iamhere.dmg).
