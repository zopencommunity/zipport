#!/bin/sh
# This script is created for testing of Zip utilities on z/os systems
# Test script is from repo "https://github.com/pirat89/zip-tests"  

export PATH="$PWD/zip:$PATH"
zip=$(echo $(/bin/type zip) | cut -f3 -d ' ')
scriptname="$(basename "$0")"
TEST_DIR="test_dir"
cd "${0%$scriptname}"
_SCRIPT_PWD="$PWD"
COMPACT=0
__tmp_output=""
only_test=""
SYSTEM=$(uname -s 2>/dev/null) || SYSTEM="unknown"

home_expand() {
  echo "$1" | grep -q "^~/" && echo "$HOME${1#\~}" || echo "$1"
}

#################################################
# USAGE
#################################################
print_usage() {
  echo "
 tests.sh [--nocolors] [--zip FILE]
          [-c | --compact VAL] [ --run-test test_function ] [-h | --help]

    --nocolors      No colored output

    --zip FILE      Will be sed this script as zip.
                    Default: $(which zip)


    --run-test test_function
                    Run only test with same name of function

    -c, --compact VAL
                    Create compact output. VAL can be number 1..5.
                    1 - suppress output from  utilities and error messages
                        and print only basic info about tests.

                    2 - print whole output and basic info about success of each
                        test print one more time after ends of tests

                    3 - similar to 2, but logged errors are print by between
                        compact output after tests are completed. In this case
                        these errors are printed to STDOUT istead of STDERR

                    4 - similar to 3 with suppressed output from utilities,
                        but prints basic info about test (it's like progress)

                    5 - similar to 4, but suppressed any output during testing

    -h, --help      Print this help.
"
}

if [[ ! -e "$zip" ]]; then
  echo "Script Error: File $zip doesn't exists." >&2
  exit 1
fi


[ -n "$TEST_DIR" ] || {
  echo "EMPTY destination of TEST_DIR!! Threatens remove of all files on disk!" >2&
  exit 2
}

rm -rf "$TEST_DIR"
mkdir "$TEST_DIR" || {
  echo "Error: test directory wasn't created!"
  exit 1
}

#################################################
# BASIC FUNCTIONS & VARS                        #
#################################################
# here are basic functions and variables for easier testing
# you can add here other functions which are helpfull for you

FAILED=0
PASSED=0
TOTAL=0
__zip_version="$($zip -v | head -n 2 | tail -n 1 | cut -d " " -f 4)"

__TEST_COUNTER=1

if [[ $NOCOLORS -eq 0 ]]; then
  green='\e[1;32m'
  red='\e[1;31m'
  cyan='\e[1;36m'
  endColor='\e[0m'
else
  green=""
  red=""
  cyan=""
  endcolor=""
fi

TEST_TITLE=""
DTEST_DIR="$TEST_DIR/$TEST_DIR" # double testdir - for unzipped files

set_title() {
  TEST_TITLE="$*"
}

clean_test_dir() {
  [ -n "$TEST_DIR" ] || {
    echo "EMPTY destination of TEST_DIR!! Threatens remove of all files on disk!" >2&
    exit 2
  }
  rm -rf "$TEST_DIR"/* > /dev/null
}

test_failed() {
  [ "$PWD" != "$_SCRIPT_PWD" ] && cd "$_SCRIPT_PWD"
  clean_test_dir
  [ $COMPACT -ne 5 ] && \
    echo -e "[  ${red}FAIL${endColor}  ] TEST ${__TEST_COUNTER}: $TEST_TITLE"
  [ $COMPACT -gt 1 ] && \
    __tmp_output="${__tmp_output}\n[  ${red}FAIL${endColor}  ] TEST ${__TEST_COUNTER}: $TEST_TITLE"
  __TEST_COUNTER=$[ $__TEST_COUNTER +1 ]
  FAILED=$[ $FAILED +1 ]
}

test_passed() {
  [ "$PWD" != "$_SCRIPT_PWD" ] && cd "$_SCRIPT_PWD"
  clean_test_dir
  [ $COMPACT -ne 5 ] && \
    echo -e "[  ${green}PASS${endColor}  ] TEST ${__TEST_COUNTER}: $TEST_TITLE"
  [ $COMPACT -gt 1 ] && \
    __tmp_output="${__tmp_output}\n[  ${green}PASS${endColor}  ] TEST ${__TEST_COUNTER}: $TEST_TITLE"
  __TEST_COUNTER=$[ $__TEST_COUNTER +1 ]
  PASSED=$[ $PASSED +1 ]
}

test_skipped() {
  [ "$PWD" != "$_SCRIPT_PWD" ] && cd "$_SCRIPT_PWD"
  clean_test_dir
  [ $COMPACT -ne 5 ] && \
    echo -e "[  ${cyan}SKIP${endColor}  ] TEST ${__TEST_COUNTER}: $TEST_TITLE"
  [ $COMPACT -gt 1 ] && \
    __tmp_output="${__tmp_output}\n[  ${cyan}SKIP${endColor}  ] TEST ${__TEST_COUNTER}: $TEST_TITLE"
  __TEST_COUNTER=$[ $__TEST_COUNTER +1 ]
  SKIPPED=$[ $SKIPPED +1 ]
}

# use this if you want print some error message
log_error() {
  echo "Error: TEST $__TEST_COUNTER: $*" >&2
  [ $COMPACT -gt 2 ] && __tmp_output="${__tmp_output}\nError: TEST $__TEST_COUNTER: $*"
}

#################################################
# OTHER USABLE FUNCTIONS                        #
#################################################
# You could use and insert here functions which are helpfull for testing.
# However you SHOULDN'T modify them, without check of every function which
# use them!

is_integer() {
  echo "$1" | grep -qE "^[0-9]+$"
  return $?
}

create_text() {
  # this nice generator is undertaken from Alan Skorkin
  # http://www.skorks.com/2010/03/how-to-quickly-generate-a-large-file-on-the-command-line-with-linux/
  # optional parameter for setting length of text

  is_integer "$1" && chars=$1 || chars=100000
  case "$SYSTEM" in
    SunOS)
      DICT_WORDS=/usr/share/lib/dict/words
      ;;
    *)
      DICT_WORDS=/usr/share/dict/words
      ;;
    esac
  echo $(ruby -e 'a=STDIN.readlines;500.times do;b=[];20.times do;
           b << a[rand(a.size)].chomp end; puts b.join(" "); end' \
     < $DICT_WORDS ) | head -c $chars
}

# create unique filename for files in $TEST_DIR
# $1 prefix
# $2 suffix
create_unique_filename() {
  echo "$1" | grep -qE "^[a-zA-Z0-9_.]+$"
  [ $? -eq 0 ] && prefix="$1" || prefix="tmp_"

  echo "$2" | grep -qE "^[a-zA-Z0-9_.]+$"
  [ $? -eq 0 ] && suffix="$2" || suffix=""

  file_counter=$( ls "$TEST_DIR" | wc -l )
  while [ 1 ]; do
    filename="${prefix}${file_counter}${suffix}"

    [ ! -e "$TEST_DIR/$filename" ] && {
       echo $filename
       return 0
    }
    file_counter=$[ $file_counter +1 ]
  done
}

# long lines - 100k characters
# parameter sets length of file - default 10k
create_text_file() {
  filename="$( echo -e "tmp_"$( ls $TEST_DIR | wc -l ))"
  is_integer "$1" && chars=$1 || chars=10000
  yes "$( create_text )" | head -c $chars > "$TEST_DIR/$filename"
  echo $filename
}

# $1 - expected return value
# $2 - real return value
test_ecode() {
  [ $# -ne 2 ] && {
    log_error "test_ecode(): wrong count of arguments!"
    return 2
  }

  [ $1 -eq $2 ] && return 0

  log_error "Wrong exit code! Expected $1, but returned $2"
  return 1
}

#################################################
# TESTS BEGIN                                   #
#################################################

#TODO: proposed tests for implementation
#### test | expected result
# create archive with really many files | ? (limit)
# create archive with symlinks | success
# add file - not exists | ?
# add file - limit reached | ?
# add file - empty archive | success
# delete file - deleted already | ?
# delete file - deleted already and empty | ?
# test really big archive? | ?
## series of can't read zip and files | failed
## series zipfile format
# error writing | 14 (can't write) - I duno how test this now
# tests for zipnote and zipcloak
## invalid comment format | 7

#################################################
# Here add test functions.
# Do not add call of function! these will be called automatically
# by this script in section TESTINGS!
# Any helpfull functions add into the section above

#skeleton
# test_X () {
#   set_title "title/label of test" # it's required! for right output report
#   # do what you want
#   ....
#   return 0 # PASSED
#   return 1 # FAILED
#   return 2 # SKIPPED
#}



# create archive | success 0
test_1 () {
  set_title "Create archive.zip - unzip, cmp verify"
  touch $TEST_DIR/test1.txt
  filename="$TEST_DIR/test1.txt"
  [ -e "$TEST_DIR/archive.zip" ] && rm archive.zip
  $zip $TEST_DIR/archive.zip $filename
  if [ $? -eq 0 ]; then
      PASSED=$[ $PASSED+1 ] 
  else
     FAILED=$[ $FAILED+1 ] 
  fi
 
}

# create archive - without extension | automatic adding of .zip
test_2 () {
  set_title "Create archive - extension adding"
  touch $TEST_DIR/test2.txt
  filename="$TEST_DIR/test2.txt"
  [ -e "$TEST_DIR/archive2.zip" ] && rm archive2.zip 
  $zip $TEST_DIR/archive2 $filename 
  [ -e "$TEST_DIR/archive2.zip" ] && PASSED=$[ $PASSED+1 ] || FAILED=$[ $FAILED+1 ]  
}

# create archive - file doesn't exists | nothing to do
test_3() {
  set_title "Create archive - file doesn't exists"
  $zip $TEST_DIR/archive3 $TEST_DIR/non_existing_file
  #test_ecode 12 $? || return 1
  [ -e "$TEST_DIR/archive3.zip" ] && {
    log_error "Archive was created but it shouldn't!"
    FAILED=$[ $FAILED+1 ]  
  } || PASSED=$[ $PASSED+1 ] 
}


# Create archive - empty filelist | nothing to do
test_4() {
  set_title "Create archive - without any file in list"
  $zip $TEST_DIR/archive4
  [ -e "$TEST_DIR/archive4.zip" ] && {
    log_error "Archive was created but it shouldn't!"
   FAILED=$[ $FAILED+1 ]
  } || PASSED=$[ $PASSED+1 ] 
} 

# update not exists archive | warning, create archive
test_5() {
  set_title "Update - archive not exists"
  touch $TEST_DIR/test5.txt
  filename="$TEST_DIR/test5.txt" 
  $zip -u $TEST_DIR/archive5 $filename 2> $TEST_DIR/log
  [ -e "$TEST_DIR/archive5.zip" ] && PASSED=$[ $PASSED+1 ]  && echo "passed 5 tst case " || \
    { log_error "Archive wasn't created"; FAILED=$[ $FAILED+1 ]; return 1; }
}

# update archive - verify with unzip | success
test_6() {
  set_title "Update archive - add new file and replace existing - unzip, cmp verify"
  touch $TEST_DIR/tmp_0 $TEST_DIR/tmp_1 $TEST_DIR/tmp_2
  filename=$TEST_DIR/tmp_2
  $zip $TEST_DIR/archive6 $TEST_DIR/tmp_0 $TEST_DIR/tmp_1
  sleep 1 # MUST BE!
  echo "Secret text" >> $TEST_DIR/tmp_0

  $zip -u $TEST_DIR/archive6.zip $filename
 # test_ecode 0 $? || return 1
  if [ $? -eq 0 ]; then
      PASSED=$[ $PASSED+1 ]
  else
     FAILED=$[ $FAILED+1 ]
  fi 
}

test_7() {
   set_title "Update archive - nothing to do"
   echo "something" > $TEST_DIR/tmp_0
   $zip $TEST_DIR/archive7 $TEST_DIR/tmp_0
   $zip -u $TEST_DIR/archive7
   if [ $? -eq 12 ]; then
      PASSED=$[ $PASSED+1 ]
   else
     FAILED=$[ $FAILED+1 ]
   fi 
}

# Do not edit next lines!
# TESTS ENDS
#################################################
# TESTINGS                                      #
#################################################
# print version of zip and unzip
echo "-----------------------------------------------------------------------
zip: $__zip_version
-----------------------------------------------------------------------"

# automatic invocation of test functions in section above
test_1
test_2
test_3
test_4
test_5
test_6
test_7

#################################################
# RESULTS                                       #
#################################################
TOTAL=$[ $FAILED + $PASSED ]
echo "================================================"
echo "=                 RESULTS                      =" 
echo "================================================"
echo "Total tests:  $TOTAL"
echo "Passed:       $PASSED"
echo "Failed:       $FAILED"

rm -rf $TEST_DIR
