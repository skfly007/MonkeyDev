# CaptainHook
Common hooking/monkey patching headers for Objective-C on Mac OS X and iPhone OS. MIT licensed

# Introduction to CaptainHook

CaptainHook is a generic hooking framework for the Objective-C 2.0 runtime designed to make hooking methods simple.

## Basic Setup

<pre><code>#import <CaptainHook/CaptainHook.h></code></pre>
Initializes CaptainHook so the fun can begin.

## Declaring Classes

Classes must be declared and loaded before they can be used with CaptainHook. *CHConstructor* blocks denote code that will be run as soon as the binary is loaded.

<pre><code>#import <CaptainHook/CaptainHook.h>
CHDeclareClass(NSString);
CHConstructor {
  CHLoadLateClass(NSString);
}</code></pre>

## Method Hooking

### Standard Method

Methods are hooked by first declaring a method using *CHMethod*, and then registering it in a constructor using *CHHook*:

<pre><code>#import <CaptainHook/CaptainHook.h>
CHDeclareClass(NSString);
CHMethod(2, void, NSString, writeToFile, NSString *, path, atomically, BOOL, flag)
{
    NSLog(@"Writing string to %@: %@", path, self);
    CHSuper(2, NSString, writeToFile, path, atomically, flag);
}

CHConstructor
{
    CHLoadClass(NSString);
    CHHook(2, NSString, writeToFile, atomically);
}</code></pre>

### Simpler Method

A simpler syntax may be used, but it is slightly less efficient and offers no control over when the hooks get registered:

<pre><code>#import <CaptainHook/CaptainHook.h>
CHDeclareClass(NSString);
CHDeclareMethod(2, void, NSString, writeToFile, NSString *, path, atomically, BOOL, flag)
{
    NSLog(@"Writing string to %@: %@", path, self);
    CHSuper(2, NSString, writeToFile, path, atomically, flag);
}</code></pre>

## New Classes at Runtime

New Classes may be created at runtime by using the *CHRegisterClass* macro:

<pre><code>#import <CaptainHook/CaptainHook.h>
CHDeclareClass(NSObject);
CHDeclareClass(MyNewClass);
CHMethod(0, id, MyNewClass, init)
{
    if ((self = CHSuper(0, MyNewClass, init))) {
        NSLog(@"Initted MyNewClass");
    }
    return self;
}

CHConstructor
{
    CHAutoreleasePoolForScope();
    CHLoadClass(NSObject);
    CHRegisterClass(MyNewClass, NSObject) {
        CHHook(0, MyNewClass, init);
    }
    [CHAlloc(MyNewClass) autorelease];
}</code></pre>

This works even for classes that can't be linked




# https://blog.csdn.net/Airths/article/details/121379091

Hook 对象方法（CHMethod + CHHook）  
Hook 对象方法（CHDeclareMethod）  
CHMethod 与 CHDeclareMethod 的区别  
Hook 类方法（CHClassMethod + CHClassHook）  
Hook 类方法（CHDeclareClassMethod）  
CHClassMethod 与 CHDeclareClassMethod 的区别  
