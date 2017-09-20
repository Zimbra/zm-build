#!/usr/bin/perl

use version;

if($ENV{CIRCLE_BRANCH} =~ "^release/([0-9]+[.][0-9]+[.][0-9]+)")
{
   print $1 . "\n";
}
else
{
   my $V = "1.0.0";

   close(STDERR);
   open(FD, "-|", "git", "ls-remote");
   while (<FD>)
   {
      if ( $_ =~ /refs.*\/release\/([0-9]+[.][0-9]+[.])([0-9]+)/ )
      {
         my $nV = $1 . ( $2 + 1 );

         if( ( version->parse($nV) <=> version->parse($V) ) gt 0 )
         {
            $V = $nV;
         }
      }
   }

   close(FD);

   print $V . "\n"
}
