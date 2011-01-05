# Copyright 2008 VMware, Inc.  All rights reserved. -- VMware Confidential
"""
HelloWorld gobuild product module.
"""

import helpers.target


class HelloWorld(helpers.target.Target):
   """
   Hello World

   The simplest gobuild integration imaginable.  Creates a build
   that does nothing but echo "Hello, World!" on the command line.
   Things obviously can get more complex from here.
   """

   def GetBuildProductNames(self):
      return { 'name':      'gsk-helloworld',
               'longname' : 'Gobuild Starter Kit - Hello World' }

   def GetClusterRequirements(self):
      return ['linux']

   def GetRepositories(self, hosttype):
      return []

   def GetCommands(self, hosttype):
      return [ { 'desc'    : 'Running hello world sample',
                 'root'    : '%(buildroot)',
                 'log'     : 'helloworld.log',
                 'command' : 'echo Hello, World!',
               } ]

   def GetStorageInfo(self, hosttype):
      return []

   def GetBuildProductVersion(self, hosttype):
      return "1.0.0"

