#!/usr/bin/perl

$| = 1; # flush output at any print i always use it

use v5.20;
use strict;
use feature "switch";
#use warnings;
use Term::ANSIColor; # adds colors to output
use JSON; # used to access config file
use Data::Dumper;

# there are all variables used in code there are no futher declarations
my %conf; # hashes used to store configuration in easly accessible form. Used a lot
my %file;

my @files; # used to store contents of directory when needed

my $configFile = "/home/pi/.easypico/pref.json";  # holds path to config file and is critical to program
my $command; # used to store command given to program 
my $mesg = "start"; # stores  messeage to show in input line like pi@raspberrypi:~/ $ in bash
my $tmp;  # these variables are used with no specific context 
my $tmp1; # just when program need additional variables to store something
my $tmp2;

my $help = <<"EOF";

easypico command summary

exit        exit easypico
new         create new project
ls          list files in sketchbook directory
open        open project
close       close project
edit        edit file in actually open project
compile     compile actually open project
upload      upload compiled project
tty         open specified serialport (needs picocom)
help        this messeage

if any of these few commands not work post problem to
https://github.com/montarcannon/easypico/
EOF
my $intro = <<"EOF";

\t#####     ##       #####  #     #     ####   #   ###   #### 
\t#        #  #     #        #   #      #   #     #     #    #
\t####    ######     #####    ###       ####   #  #     #    #
\t#      #      #         #    #        #      #  #     #    #
\t##### #        #  ######     #        #      #   ###   #### 
EOF

printf colored($intro, "bright_green"); 
printf colored("\tsimpler usage of your RPi pico\n", "green"); # nice intro 

# this part reads cofig file of if file not exsist creates one

if(-e $configFile){ # if file exist
    print "using config file: ". $configFile . "\n";
    open(CONFIG, "<". $configFile) or die $!; # reads it
    %conf = %{from_json <CONFIG>};
    close(CONFIG);
}
else{ # if not ask some questions and create config 
    print colored("you haven't config file!\n", "yellow");
    print "creating config file\n";
    system("touch ".$configFile);

    print colored("Please provide absolute path\n","bright_yellow bold");
    print "enter sketchbook directory path: ";
    chomp($conf{"basePath"} = <STDIN>);

    print "enter template folder path : ";
    chomp($conf{"templPath"} = <STDIN>);

    print "what editior do you prefer? : ";
    chomp($conf{"editor"} = <STDIN>);

    system "mkdir ~/.easypico/";
    open(CONFIG, ">". $configFile) or die $!;
    print CONFIG to_json(\%conf);
    close(CONFIG);
}
print colored("I'am ready to work for you! \"?\" to get help\n \"exit\" to exit","green bold"); # it's for a programmer at start of command loop
  
while(1==1){ # command executing loop
    
    print $mesg . " > ";
    chomp($command = <STDIN>); # get command

    given($command){

	when ("exit") {exit;} # a exit command
	when ("new") { # add a new file from template
	    printf "do you want to %s new sketch? yes or no : ", colored("CREATE", "underline");
	    chomp($tmp = <STDIN>); # ask user for confirmation (idiotproofness +1)
	    
	    if($tmp eq "yes"){
		print "so name it: ";
		chomp($file{"name"} = <STDIN>); # get name of sketch
 
		system("cp -rf " .$conf{"templPath"} ." ".$conf{"basePath"}."/". $file{'name'}); # copy template folder under name provided by user
		system("mv " . $conf{"basePath"}."/". $file{"name"} . "/blink.c " .$conf{"basePath"}."/". $file{"name"} . "/" . $file{"name"}.".c");
		
		open(FH, "<".$conf{"basePath"}."/".$file{"name"}."/CMakeLists.txt.templ") or die $!; # open template CMakeLists.txt
		open(FH2,">>".$conf{"basePath"}."/".$file{"name"}."/CMakeLists.txt") or die $!; # create CMakeLists.txt

		while(<FH>){ # this loop copies template CMakeLists.txt and repaces markers with data
		    $tmp =  $_ =~ s/repl/$file{"name"}/r;
		    print FH2 $tmp =~ s/fname/$file{"name"}.c/r;
		}
		close(FH); # close filehandles
		close(FH2);
		system("rm -rf ".$conf{"basePath"}."/".$file{"name"}."/CMakeLists.txt.templ"); # remove template CMakeLists.txt we don't need it anymore in project folder
		$file{"open"} = 1;
		$file{"compiled"} = 0;
		$mesg = $file{"name"};
		open(FILECONF, ">". $conf{"basePath"}."/".$file{"name"}."/project.json") or die $!;
		print FILECONF to_json(\%file);
		close(FILECONF);
	    }
	    else{
		print "back to main\n";
	    }
	}



	when("edit"){ # We need to edit files. Sometimes...
	    if($file{"open"} == 0){
		print "you haven't open project ";
		break;
	    }
	    opendir my $dir, $conf{'basePath'} ."/".  $file{"name"} or die $!;
	    @files = readdir $dir;
	    closedir $dir;
	    
	    print colored("what file you want to edit\n","bright_green"); # print nice menu
	    $tmp = 0;
	    foreach(@files){
		printf "%s %s\n", $tmp++, $_;
		
	    }
	    
	    print colored("enter number: ","green"); # ask for number
	    chomp($tmp1 = <STDIN>);
	    
	    $tmp2 = $files[$tmp1] or break;
	    print system($conf{"editor"}." ".$conf{"basePath"}."/".$file{"name"}."/".$tmp2."\n")."\n"; # run bash command to edit
	    
	}


	when("open"){ # opens recent project
	    print colored("tell me name of file to open!\n","bright_green");
	    print "name : ";
	    chomp($tmp = <STDIN>); # get number of file that user want to edit
	    if(-d $conf{"basePath"}."/".$tmp){
		print colored("opening project: ".$tmp."\n","bright_green bold");
		open(FILECONF, "<". $conf{"basePath"}."/".$tmp."/project.json") or die $!; # read configuration of project it is a saved %file hash
		%file = %{from_json <FILECONF>}; 
		close(FILECONF);
		$mesg = $tmp; # set mesg to name of opened project
	    }
	}
	when("close"){ #close project
	    print colored("closing file ".$file{"name"}."\n", "bright_green bold");
	    if(-e $conf{"basePath"}."/".$file{"name"}."/project.json"){
	    open(FILECONF, ">". $conf{"basePath"}."/".$file{"name"}."/project.json") or die $!; # save configuraton
	    print FILECONF to_json(\%file);
	    close(FILECONF);
	    $file{"name"} = "";
	    $file{"open"} = 0;
	    $file{"compiled"} = 0;
	    $mesg = "start"; # set mesg to "start" it indicates bo opened file
	    }
	    else{
		print colored("you haven't project file!.","bright_yellow bold"); 
	    }
	}
	when("compile"){ #compiles code essential program function
	    if($file{"open"} == 0){
		print colored("first open file","bright_yellow bold");
		break;
	    }
	    else{
		print colored("Compiling project: ".$file{"name"}."\n","bright_green bold");
		chdir($conf{"basePath"}."/".$file{"name"}."/build");
		print system("cmake ..")."\n";
		print system("make -j4")."\n";
		$file{"compiled"} = 1;
	    }
	}
	when("upload"){ #upload code to rpi pic0
	    if($file{"compiled"} == 1){
		print system("picotool load ".$conf{"basePath"}."/".$file{"name"}."/build/".$file{"name"}.".uf2")."\n";
	    }
	    else{
		print colored("please compile first!","bright_yellow bold");
	    }
	}
	
	when("dump"){ # debug
	    print "%conf:\n".Dumper(%conf)."%file:\n".Dumper(%file); # debug confg
	}
	when("tty"){ # serialport
	    print colored("serialport to open: ","bright_green bold");
	    chomp($tmp1 = <STDIN>);
	    print colored("baud: ", "bright_green bold");
	    chomp($tmp = <STDIN>);
	    print system("sudo picocom"." -b".$tmp." ".$tmp1)."\n"; # start serial communication program
	}
	when("ls"){ #lists directories simple function
	    opendir my $dir, $conf{'basePath'} ."/" or die $!;
	    @files = readdir $dir;
	    closedir $dir;
	    foreach(@files){
		print $_."\n";
	    }
	}
    when("reboot"){ # reboots rpi pico
        print system("picotool reboot")."\n";
    }
    when("help"){ # help who user that don't know commands
        print colored($help,"bold");
        }
    }       
}
