#!/usr/bin/env bash
echo "=====================Performance test for $endpoint with $studentsCount students and $teachersCount teachers====================="

#HOSTS=(20.46.44.23 20.46.44.71 20.46.44.98 20.46.44.100 20.46.44.137 20.46.44.141)
HOSTS=(172.31.29.149 172.31.28.209 172.31.28.96 172.31.22.103 172.31.30.92)
HOSTNAMES=(jmeter1.alefed.com jmeter2.alefed.com datapump.alefed.com jmeter3.alefed.com jmeter5.alefed.com)

USER_NAME='centos'

FILENAME=students.csv
if [ ! -f students.csv ]; then
    FILENAME=data/students.csv
fi

#HDR=$(head -1 $FILENAME)
HDR="username,password,realUserId,realK12Grade,realCurrentAcademicYearId"
PART_PATTERN=fileParts/students.part.

TEACHER_FILENAME=teachers.csv
if [ ! -f teachers.csv ]; then
    TEACHER_FILENAME=data/teachers.csv
fi

TEACHER_PART_PATTERN=fileParts/teachers.part.

GIT_PROJ_NAME=alef-perf-test
GATLING_OUTPUT_DIR=target/gatling
GATHER_REPORTS_DIR=$GATLING_OUTPUT_DIR/reports
ERROR_LOG_FILE=$GATLING_OUTPUT_DIR/simulation-errors.log
FLAG_FILE=$GIT_PROJ_NAME/simulation-done.txt
SIMULATION_RUN_FILE=$GIT_PROJ_NAME/runSimulation.sh

rm -rf fileParts
mkdir fileParts

if $studentJourneyEnabled || $assignmentEnabled; then
  split -d -l ${studentsCount} $FILENAME $PART_PATTERN
fi

if $teacherJourneyEnabled || $assignmentEnabled; then
  split -d -l ${teachersCount} $TEACHER_FILENAME $TEACHER_PART_PATTERN
fi

for index in ${!HOSTS[@]}; do
    if $studentJourneyEnabled || $assignmentEnabled; then
      sed -i 1i$HDR ${PART_PATTERN}0${index}
    fi

    if $teacherJourneyEnabled || $assignmentEnabled; then
      sed -i 1i$HDR ${TEACHER_PART_PATTERN}0${index}
    fi
done


for HOST in "${HOSTS[@]}"
do
  echo "Cleaning gatling project: $HOST"
  ssh $USER_NAME@$HOST "rm -rf alef-perf-test"
done

for index1 in ${!HOSTS[@]}
do
  echo "Checking out gatling project: ${HOSTS[$index1]}"
  ssh $USER_NAME@${HOSTS[$index1]} "git clone -b develop git@github.com:AlefEducation/alef-perf-test.git"

  if $studentJourneyEnabled || $assignmentEnabled; then
    scp -r ${PART_PATTERN}0${index1} $USER_NAME@${HOSTS[$index1]}:alef-perf-test/src/test/resources/students.part.0${index1}.csv
  fi

  if $teacherJourneyEnabled || $assignmentEnabled; then
    scp -r ${TEACHER_PART_PATTERN}0${index1} $USER_NAME@${HOSTS[$index1]}:alef-perf-test/src/test/resources/teachers.part.0${index1}.csv
  fi

done

for index2 in ${!HOSTS[@]}
do
  echo "Running simulation on host: ${HOSTS[$index2]}"
  ssh -n -f $USER_NAME@${HOSTS[$index2]} "chmod +x $SIMULATION_RUN_FILE && nohup $SIMULATION_RUN_FILE clean gatling:test -Dgatling.charting.noReports=true  -Durl=${endpoint} -DstudentsCount=${studentsCount} -DstudentsRampUp=${studentsRampUp} -DsubmitAnswerJson=${submitAnswerJson} -DstudentUserFile=students.part.0${index2}.csv -DmloCount=${mloCount} -DpauseBetweenRequestsMs=${pauseBetweenRequestsMs} -DpauseBetweenQuestions=${pauseBetweenQuestions} -DpauseBetweenAssessments=${pauseBetweenAssessments} -DalefAssessmentPoolsFeeder=${alefAssessmentPoolsFeeder} -DpauseBetweenQuestionAttempts=${pauseBetweenQuestionAttempts} -DlongPauseMs=${longPauseMs} -DmloPauseMs=${mloPauseMs} -DexpPauseMs=${expPauseMs} -DloadModel=${loadModel} -DenableAATFlow=${enableAATFlow} -Dscore=${score} -DstudentJourneyEnabled=${studentJourneyEnabled} -DdataVolumeEnabled=${dataVolumeEnabled} -DteacherJourneyEnabled=${teacherJourneyEnabled} -DteachersCount=${teachersCount} -DteachersRampUp=${teachersRampUp} -DteacherLoop=${teacherLoop} -DteacherUserFile=teachers.part.0${index2}.csv -DnotificationsRunTime=${notificationsRunTime} -Dgatling.simulationClass=com.alefeducation.${simulation} -DtestDuration=${testDuration} -DonBoardStudentEnabled=${onBoardStudentEnabled} -DteacherPageNavigationTT=${teacherPageNavigationTT} -DteacherScnRps=${teacherScnRps} -DstudentPageNavigationTT=${studentPageNavigationTT} -DteacherAssignmentTT=${teacherAssignmentTT} -DassignmentEnabled=${assignmentEnabled} -DassignmentLoop=${assignmentLoop} -DstudentsThroughputRampUp=${studentsThroughputRampUp} -DcommonAccessToken=${commonAccessToken} -DstudentsThroughputDelay=${studentsThroughputDelay} -Dgatling.data.graphite.rootPathPrefix=gatling.${HOSTNAMES[$index2]} -DdataVolumeStudentStars=${dataVolumeStudentStars} -DstudentCommonAccessToken=${studentCommonAccessToken} -DteacherCommonAccessToken=${teacherCommonAccessToken} &"
done

# ================== steps to run simulation on local based on jenkins parameter value (useMaster)==================

if $useMaster; then

    if $studentJourneyEnabled || $assignmentEnabled; then
      sed -i 1i$HDR ${PART_PATTERN}0${#HOSTS[@]}
      echo "Copy students file  on local"
      cp ${PART_PATTERN}0${#HOSTS[@]} src/test/resources/students.part.0${#HOSTS[@]}.csv
    fi

    if $teacherJourneyEnabled || $assignmentEnabled; then
      sed -i 1i$HDR ${TEACHER_PART_PATTERN}0${#HOSTS[@]}
      echo "Copy teachers file  on local"
      cp ${TEACHER_PART_PATTERN}0${#HOSTS[@]} src/test/resources/teachers.part.0${#HOSTS[@]}.csv
    fi

    echo "Running simulation on local"
    ./mvnw clean gatling:test -Dgatling.charting.noReports=true -Durl=${endpoint} -DstudentsCount=${studentsCount} -DstudentsRampUp=${studentsRampUp}  -DstudentUserFile=students.part.0${#HOSTS[@]}.csv -DmloCount=${mloCount} -DpauseBetweenRequestsMs=${pauseBetweenRequestsMs} -DpauseBetweenQuestionAttempts=${pauseBetweenQuestionAttempts} -DlongPauseMs=${longPauseMs} -DmloPauseMs=${mloPauseMs} -DexpPauseMs=${expPauseMs} -DloadModel=${loadModel} -DenableAATFlow=${enableAATFlow} -Dscore=${score} -DstudentJourneyEnabled=${studentJourneyEnabled} -DteacherJourneyEnabled=${teacherJourneyEnabled} -DprincipalEnabled=${principalEnabled} -DdataVolumeEnabled=${dataVolumeEnabled} -DteachersCount=${teachersCount} -DteachersRampUp=${teachersRampUp} -DteacherLoop=${teacherLoop} -DteacherUserFile=teachers.part.0${#HOSTS[@]}.csv -Dgatling.simulationClass=com.alefeducation.${simulation} -DtestDuration=${testDuration} -DonBoardStudentEnabled=${onBoardStudentEnabled} -DteacherPageNavigationTT=${teacherPageNavigationTT} -DteacherScnRps=${teacherScnRps} -DstudentPageNavigationTT=${studentPageNavigationTT} -DteacherAssignmentTT=${teacherAssignmentTT} -DassignmentEnabled=${assignmentEnabled} -DassignmentLoop=${assignmentLoop} -DstudentsThroughputRampUp=${studentsThroughputRampUp} -DcommonAccessToken=${commonAccessToken} -DstudentsThroughputDelay=${studentsThroughputDelay} -Dgatling.data.graphite.rootPathPrefix=gatling.${HOSTNAME} -DdataVolumeStudentStars=${dataVolumeStudentStars} -DstudentCommonAccessToken=${studentCommonAccessToken} -DteacherCommonAccessToken=${teacherCommonAccessToken}
fi

# ================== check whether simulation is complete on all agents ==================
c=0
while [ $c -lt ${#HOSTS[@]} ]
do
	c=0
	for HOST in "${HOSTS[@]}"
    do
        if ssh $USER_NAME@$HOST "test -e $FLAG_FILE"; then
          echo "Simulation completed on $HOST"
          ((c+=1))
        else
          echo "Waiting till agents finishes simulation on $HOST"
          sleep 60
        fi
    done
done

sleep 20

# ================== collect simulations from all agents to generate final report ==================

echo "Create $GATHER_REPORTS_DIR directory  in local to gather result files from clients"
mkdir -p $GATHER_REPORTS_DIR

if $useMaster; then
  echo "Gathering result file from local"
  mv target/gatling/alef*-* $GATHER_REPORTS_DIR

  echo "Gathering error file from local"
  mv $ERROR_LOG_FILE ${GATHER_REPORTS_DIR}/simulation-errors-local.log
fi

for HOST in "${HOSTS[@]}"
do
  echo "Gathering result file from host: $HOST"
  ssh $USER_NAME@$HOST "mv $GIT_PROJ_NAME/$GATLING_OUTPUT_DIR/alef*-* $GIT_PROJ_NAME/$GATHER_REPORTS_DIR"
  scp $USER_NAME@$HOST:$GIT_PROJ_NAME/$GATHER_REPORTS_DIR/simulation.log ${GATHER_REPORTS_DIR}/simulation-$HOST.log

  echo "Gathering error file from host: $HOST"
  scp $USER_NAME@$HOST:$GIT_PROJ_NAME/$ERROR_LOG_FILE ${GATHER_REPORTS_DIR}/simulation-errors-$HOST.log
done

# ================== collect simulations from all agents to generate final report ==================
./mvnw gatling:test -Dgatling.reportsOnly=reports
