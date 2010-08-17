#!/bin/bash

unset SSH_AGENT_PID
unset SSH_AUTH_SOCK

work_dir=$1
bkdate=`date +%s`
function on_exit()
{
    echo "Cleaning up! $bkdate"
    if [ "X$work_dir" == "X" ]; then
        rm -rf $work_dir
    fi
    rm -rf $HOME/.nimbus
    rm -rf $HOME/.globus
    rm -rf $HOME/.ssh
    mv $HOME/.nimbus.$bkdate $HOME/.nimbus
    mv $HOME/.globus.$bkdate $HOME/.globus
    mv $HOME/.ssh.$bkdate $HOME/.ssh
}

if [ "X$work_dir" == "X" ]; then
    work_dir=`mktemp --tmpdir=$HOME -d -t tmp.XXXXXXXXXX`
    mv $HOME/.ssh $HOME/.ssh.$bkdate
    mv $HOME/.nimbus $HOME/.nimbus.$bkdate
    mv $HOME/.globus $HOME/.globus.$bkdate
    trap on_exit EXIT
fi

bd=`dirname $0`
cd $bd
src_dir=`pwd`

if [ "X$2" == "Xno" ]; then
    echo "we are kiping the build and just running the tests"
else
    echo "Building a Nimbus env at $work_dir"
    ./make-test-env.sh $work_dir | tee bandt.log
fi
source env.sh

cd $CLOUD_CLIENT_HOME
./bin/grid-proxy-init.sh

echo "========================================="
echo "Starting the services"
echo "========================================="
cd $NIMBUS_HOME
pkill cumulus
./bin/nimbusctl restart
if [ $? -ne 0 ]; then
    echo "something somewhere went wrong. look through the output above"
    echo "and check the log files.  There is possibly already a service running"
    echo "or something else is claiming the needed ports."
    exit 1
fi

echo "========================================="
echo "Run tests...."
echo "========================================="
cd $src_dir

cnt="0"
error_cnt="0"
error_ts=""
for t in *test.{sh,py}
do
    ./$t 2>&1 | tee $t.log
    if [ $PIPESTATUS -ne 0 ]; then
        echo "$cnt parent tests passed (many more subtests were run)"
        echo "the test $t failed"
        error_cnt=`expr $error_cnt + 1`
        error_ts="$error_ts $t"
    else
        cnt=`expr $cnt + 1`
    fi
done
echo "$cnt parent tests passed (many more subtests were run)"
echo "$error_cnt parent tests failed"
echo "    $error_ts"

$NIMBUS_HOME/bin/nimbusctl stop
exit $error_cnt
