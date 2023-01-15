#!/bin/bash -eu
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

MAVEN_ARGS="-P!java14+ -Dmaven.test.skip=true -Djavac.src.version=15 -Djavac.target.version=15"

cd $SRC/jackson-dataformats-binary
mvn package $MAVEN_ARGS
CURRENT_VERSION=$(mvn org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate \
 -Dexpression=project.version -q -DforceStdout)
DATAFORMAT_PREFIX=jackson-dataformat
cp "cbor/target/$DATAFORMAT_PREFIX-cbor-$CURRENT_VERSION.jar" $OUT/$DATAFORMAT_PREFIX-cbor.jar
cp "smile/target/$DATAFORMAT_PREFIX-smile-$CURRENT_VERSION.jar" $OUT/$DATAFORMAT_PREFIX-smile.jar

PROJECT_JARS="$DATAFORMAT_PREFIX-cbor.jar $DATAFORMAT_PREFIX-smile.jar"

DEPENDENCIES="jackson-core jackson-databind jackson-annotations"
for dependency in $DEPENDENCIES; do
  cd $SRC/$dependency
  mvn package $MAVEN_ARGS
  current_version=$(mvn org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate \
  -Dexpression=project.version -q -DforceStdout)
  cp "target/$dependency-$current_version.jar" $OUT/$dependency.jar
done

FUZZER_JARS=$(echo $DEPENDENCIES | xargs printf -- "%s.jar ")

ALL_JARS="$PROJECT_JARS $FUZZER_JARS"

# The classpath at build-time includes the project jars in $OUT as well as the
# Jazzer API.
BUILD_CLASSPATH=$(echo $ALL_JARS | xargs printf -- "$OUT/%s:"):$JAZZER_API_PATH

# All .jar and .class files lie in the same directory as the fuzzer at runtime.
RUNTIME_CLASSPATH=$(echo $ALL_JARS | xargs printf -- "\$this_dir/%s:"):\$this_dir

for fuzzer in $(find $SRC -name '*Fuzzer.java'); do
  fuzzer_basename=$(basename -s .java $fuzzer)
  javac -cp $BUILD_CLASSPATH $fuzzer
  cp $SRC/$fuzzer_basename.class $OUT/

  # Create an execution wrapper that executes Jazzer with the correct arguments.
  echo "#!/bin/bash
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname \"\$0\")
if [[ \"\$@\" =~ (^| )-runs=[0-9]+($| ) ]]; then
  mem_settings='-Xmx1900m:-Xss900k'
else
  mem_settings='-Xmx2048m:-Xss1024k'
fi
LD_LIBRARY_PATH=\"$JVM_LD_LIBRARY_PATH\":\$this_dir \
\$this_dir/jazzer_driver --agent_path=\$this_dir/jazzer_agent_deploy.jar \
--cp=$RUNTIME_CLASSPATH \
--target_class=$fuzzer_basename \
--jvm_args=\"\$mem_settings\" \
\$@" > $OUT/$fuzzer_basename
  chmod +x $OUT/$fuzzer_basename
done
