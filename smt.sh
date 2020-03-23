#!/bin/sh

# **************
# *** Target ***
# **************
. ./config.env

#Refresh level
counter=5 #Refresh
level1=$counter
level2=60

first_exec=1

function delete_logs ()
{
  if [ -d "log" ]; then
    rm -f ./log/*.log
  else
    mkdir ./log/
  fi
}

function create_tmp ()
{
  if [ ! -d $tmp ]; then
    mkdir $tmp
  fi
}

function variables ()
{
  l=$1
  c=$2
  tput cup $l $c
  printf "${c_header}Variables:${c_r}"
  l=$(($l+1));tput cup $l $c
  if [ ! -z $SP_SYS_VARDIR ]; then
    printf "SP_SYS_VARDIR : ${c_green}OK${c_default}"
  else
    printf "SP_SYS_VARDIR : ${c_red}KO${c_default}"
  fi
  tput cup $l $c
  l=$(($l+1));tput cup $l $c
  if [ ! -z $SP_SYS_PRODDIR ]; then
    printf "SP_SYS_PRODDIR: ${c_green}OK${c_default}"
  else
    printf "SP_SYS_PRODDIR: ${c_red}KO${c_default}"
  fi
  tput cup $l $c
  l=$(($l+1));tput cup $l $c
  if [ ! -z $SP_COP_TPORT ]; then
    printf "SP_COP_TPORT  : ${c_green}OK${c_default}"
  else
    printf "SP_COP_TPORT  : ${c_red}KO${c_default}"
  fi
  tput cup $l $c
  l=$(($l+1));tput cup $l $c
  if [ ! -z $SP_COP_UPORT ]; then
    printf "SP_COP_UPORT  : ${c_green}OK${c_default}"
  else
    printf "SP_COP_UPORT  : ${c_red}KO${c_default}"
  fi
  
  
}

function colorize ()
{
cat > $tmp/colorize <<EOF
awk '
function color(c,s) {
        printf("\033[%dm%s\033[0m\n",30+c,s)
}
/error/ {color(1,\$0);next}
/Running/ {color(2,\$0);next}
/Stopped by user/ {color(3,\$0);next}
/Process/ {color(4,\$0);next}
/Idle/ {color(5,\$0);next}
{print}
' \$1
EOF
chmod 777 $tmp/colorize
}

function host ()
{
  l=$1
  c=$2
  tput cup $l $c
  printf "\e[1mHost:\e[21m\e[4m$SP_SYS_HOST_NAME\e[24m"
}

function shareplex_config ()
{
  l=$1
  c=$2
  tput cup $l $c
  shareplex_file=`echo "list config" | sp_ctrl | grep "Active" | awk '{print $1}'`
  printf "SharePlex Active Config File:$shareplex_file"
}

function objects ()
{
  l=$1
  c=$2
  echo "show config" | sp_ctrl | grep "Total Objects" > $tmp/total_objects

  tput cup $l $c
  printf "${c_header}Total Database Objects:$c_r\n"
  cat $tmp/total_objects
}

function datasource() {
  l=$1
  c=$2
  tput cup $l $c
  config_file=`echo "list config" | sp_ctrl | grep "Active" | awk '{print $1}'`
  cat $SP_SYS_VARDIR/config/$config_file | grep datasource | awk '{print $1}'
}

function process ()
{
  # ***************
  # *** Process ***
  # ***************
  l=$1
  c=$2
  ps -Ao user,comm,pid,pcpu --sort=-pcpu | grep -E "USER|sp_" | head -n 4 > $tmp/cpu
  tput cup $l $c
  printf "${c_header}Source Process (3 max order by cpu):$c_r\n"
  l=$(($l+1))
  while IFS= read -r line
  do
    tput cup $l $c
    echo "$line"
    l=$(($l+1))
    tput cup $l $c
  done < $tmp/cpu

}

function version()
{
  l=$1
  c=$2
  tput cup $l $c
  version=`echo "version" | sp_ctrl | grep Version | awk '{print $4}'`
  printf "\e[104m*** SharePlex Monitoring 0.1 ***\e[49m SharePlex Version: \e[34m$version\e[0m"
}

function cpu()
{
  l=$1
  c=$2
  tput cup $l $c
  cpu=`top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'`

  tput cup $l $c
  echo "                          "
  tput cup $l $c
  printf "CPU: \e[1m ${c_green} %-10s ${c_default}" ${cpu}
}

function queues ()
{
  l=$1
  c=$2
  tput cup $l 0
  echo "qstatus" | sp_ctrl | grep -E "Queue|Name|Number|Backlog" > $tmp/qstatus
  printf "${c_header}Queue Statistics:$c_r\n"
  cat $tmp/qstatus
  qstatus=`echo "qstatus" | sp_ctrl | grep -E "Queue|Name|Number|Backlog" | wc -l`
  
  ll=$(($l+2+$qstatus))

  tput cup $ll 0
  echo "show" | sp_ctrl | grep -E "Process|Capture|Read|Export|Post|Import|-" > $tmp/show
  printf "${c_header}Source Queues:$c_r\n"
  $tmp/colorize $tmp/show
  count_show=`cat $tmp/show | wc -l`
  
  #Queues
  cq=`grep "Capture queue" $tmp/qstatus | wc -l`
  rq=`grep "Read queue" $tmp/qstatus | wc -l`
  eq=`grep "Export queue" $tmp/qstatus | wc -l`
  iq=`grep "Import queue" $tmp/qstatus | wc -l`
  pq=`grep "Post queue" $tmp/qstatus | wc -l`

  tput cup 0 $c
  printf "Number of Capture queues : ${c_green} $cq ${c_default}"
  tput cup 1 $c
  printf "Number of Read queues    : ${c_green} $rq ${c_default}"
  tput cup 2 $c
  printf "Number of Export queues  : ${c_green} $eq ${c_default}"
  tput cup 3 $c
  printf "Number of Import queues  : ${c_green} $iq ${c_default}"
  tput cup 4 $c
  printf "Number of Post queues    : ${c_green} $pq ${c_default}"
  
  ll=$(($ll+$l-4))
  target_queues $ll 0

}

function counters ()
{
  l=0
  c=58
  tput cup $l $c
  printf "Refresh: $1"
  tput cup 1 $c
  printf "Lines: $2"
  tput cup 2 $c
  printf "Cols: $3"
}

dir_size ()
{
  l=$1
  c=$2
  # Queue Directory Size
  ds=`du -Ph $SP_SYS_VARDIR | grep rim | awk '{print $1}'`
  tput cup $l $c
  printf "${c_header}Queue Size:$c_r\n"
  l=$(($l+1))
  tput cup $l $c
  printf "Queue Directory Size: ${c_green} $ds ${c_default}"
}

function target_queues() {
  if [ $target_active = "N" ]; then
    return 0
  fi
  l=$1
  c=0
  show=$(eval "ssh $target_oracle_user@$target_host '$target_script;echo -e \"show\n\" | $target_sp_ctrl' | grep -E \"Process|Capture|Read|Export|Post|Import|-\"> $tmp/target_queues")
  tput cup $l $c
  printf "${c_header}Target Queues:$c_r\n"
  $tmp/colorize $tmp/target_queues
}

function menu()
{
  l=$(($LINES-1))
  tput cup $l 0
  printf "Q|ESC:${c_header}Quit${c_r} L:${c_header}Event log${c_r}"
}

function logs()
{
  l=0
  c=$LINES
  tput civis
  tput reset
  tput cup 0 0
  printf "${c_header}SharePlex Logs${c_r}"
  l_lines=$(($LINES-4))
  l_columns=$(($COLUMNS-2))
  tail -$l_lines $SP_SYS_VARDIR/log/event_log | cut -c 1-$l_columns > ./tmp/logs
  
  l=$(($l+2))
  while IFS= read -r line
  do
    tput cup $l 0
    echo "$line"
    l=$(($l+1))
  done < .$tmp/logs
  menu
  tput civis
  read -n 1 -r key
  clear
  first_exec=1
  menu="m"
}

# ----------------------------------
main () {
  

  tput civis # cursor invisible
  while [ true ]
  do

    # Running
    notrunning=0
    notrunning=`ps -Ao comm | grep sp_cop | grep -v grep | wc -l`
    if [ $notrunning -eq 0 ] ; then
      clear
      if [ $debug = "Y" ] ; then
        echo "Debug:"
        echo "counter: $counter"
        echo "notrunning: $notrunning"
        echo "level: $level1"
        echo "lines: $LINES"
        echo "columns: $COLUMNS"
      fi
      echo "SharePlex not running"
      tput cnorm
      exit;
    fi
    
    if [ $first_exec = 1 ] ; then
      clear
      tput civis # cursor invisible
      tput reset #

      version 0 0 
      colorize
      delete_logs
      create_tmp

      dir_size 4 0
      menu 
      first_exec=0
    fi

    if [ $menu = "l" ]; then
      logs
    fi
    
    if [ $menu = "m" ]; then
      counters $counter $LINES $COLUMNS
      cpu 1 0
      host 1 12
      shareplex_config 2 0
      objects 7 0
      process 6 39
      variables 6 80
      
      #level1 refresh
      if [ `expr $counter % $level1` -eq 0 ]; then
        queues 12 69
        counter=5
        process 6 39
      fi

      #level2 refresh
      if [ `expr $counter % $level2` -eq 0 ]; then
        dir_size 4 0
      fi
    fi
    
    tput civis
    read -t 1 -n 1 -r key
    
    case $key in
      
      c)
      menu="c"
      version
      clear;;
      
      l)
      clear
      menu="l"
      logs;;
      
      $'\x1b'|q) # ESC 
      tput cnorm;
      clear;
      exit;;
    esac
    
    counter=$(($counter-1))
  done
}

menu="m"
main
