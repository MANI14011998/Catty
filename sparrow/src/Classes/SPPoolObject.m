//
//  SPPoolObject.m
//  Sparrow
//
//  Created by Daniel Sperl on 17.09.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPPoolObject.h"
#import <malloc/malloc.h>

#define COMPLAIN_MISSING_IMP @"Class %@ needs this code:\n\
+ (SPPoolInfo *) poolInfo\n\
{\n\
  static SPPoolInfo *poolInfo = nil;\n\
  if (!poolInfo) poolInfo = [[SPPoolInfo alloc] init];\n\
  return poolInfo;\n\
}"

@implementation SPPoolInfo
// empty
@end

#ifndef DISABLE_MEMORY_POOLING

@implementation SPPoolObject
{
    SPPoolObject *_poolPredecessor;
    uint _retainCount;
}

+ (id)allocWithZone:(NSZone *)zone
{
    SPPoolInfo *poolInfo = [self poolInfo];
    if (!poolInfo->poolClass) // first allocation
    {
        poolInfo->poolClass = self;
        poolInfo->lastElement = NULL;
    }
    else 
    {
        if (poolInfo->poolClass != self)
            [NSException raise:NSGenericException format:COMPLAIN_MISSING_IMP, self];
    }
    
    if (!poolInfo->lastElement) 
    {
        // pool is empty -> allocate
        SPPoolObject *object = NSAllocateObject(self, 0, NULL);
        object->_retainCount = 1;
        return object;
    }
    else 
    {
        // recycle element, update poolInfo
        SPPoolObject *object = poolInfo->lastElement;
        poolInfo->lastElement = object->_poolPredecessor;

        // zero out memory. (do not overwrite isa & _poolPredecessor, thus the offset)
        unsigned int sizeOfFields = sizeof(Class) + sizeof(SPPoolObject *);
        memset((char*)(id)object + sizeOfFields, 0, malloc_size(object) - sizeOfFields);
        object->_retainCount = 1;
        return object;
    }
}

- (uint)retainCount
{
    return _retainCount;
}

- (id)retain
{
    ++_retainCount;
    return self;
}

- (oneway void)release
{
    --_retainCount;
    
    if (!_retainCount)
    {
        SPPoolInfo *poolInfo = [isa poolInfo];
        self->_poolPredecessor = poolInfo->lastElement;
        poolInfo->lastElement = self;
    }
}

- (void)purge
{
    // will call 'dealloc' internally --
    // which should not be called directly.
    [super release];
}

+ (int)purgePool
{
    SPPoolInfo *poolInfo = [self poolInfo];    
    SPPoolObject *lastElement;    
    
    int count=0;
    while ((lastElement = poolInfo->lastElement))
    {
        ++count;        
        poolInfo->lastElement = lastElement->_poolPredecessor;
        [lastElement purge];
    }
    
    return count;
}

+ (SPPoolInfo *)poolInfo
{
    [NSException raise:NSGenericException format:COMPLAIN_MISSING_IMP, self];
    return 0;
}

@end

#else

@implementation SPPoolObject

+ (SPPoolInfo *)poolInfo 
{
    return nil;
}

+ (int)purgePool
{
    return 0;
}

@end


#endif