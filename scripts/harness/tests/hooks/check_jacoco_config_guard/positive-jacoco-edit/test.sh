#!/usr/bin/env bash
# Positive: modify a line INSIDE the jacoco-maven-plugin block and verify
# that check_jacoco_config_guard emits a VIOLATION mentioning JaCoCo.
set -euo pipefail

. "$REPO_ROOT_REAL/scripts/harness/lib/hook-checks.sh"

git init -q
git config user.email test@example.com
git config user.name test

cat > pom.xml <<'POM'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>test</groupId>
  <artifactId>test</artifactId>
  <version>0.0.1</version>
  <dependencies>
    <dependency>
      <groupId>org.example</groupId>
      <artifactId>thing</artifactId>
      <version>1.0</version>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>com.diffplug.spotless</groupId>
        <artifactId>spotless-maven-plugin</artifactId>
        <version>3.4.0</version>
        <configuration>
          <java>
            <googleJavaFormat/>
          </java>
        </configuration>
      </plugin>
      <plugin>
        <groupId>org.jacoco</groupId>
        <artifactId>jacoco-maven-plugin</artifactId>
        <version>0.8.14</version>
        <executions>
          <execution>
            <id>check</id>
            <goals>
              <goal>check</goal>
            </goals>
            <configuration>
              <rules>
                <rule>
                  <element>BUNDLE</element>
                  <limits>
                    <limit>
                      <counter>LINE</counter>
                      <value>COVEREDRATIO</value>
                      <minimum>0.80</minimum>
                    </limit>
                  </limits>
                </rule>
              </rules>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
POM

git add pom.xml
git -c commit.gpgsign=false commit -qm "initial pom" >/dev/null

# Lower the threshold — this is the exact anti-pattern the guard blocks.
sed -i.bak 's|<minimum>0.80</minimum>|<minimum>0.70</minimum>|' pom.xml
rm -f pom.xml.bak

# Direct-invoke the dispatcher contract exports.
export TOOL=Edit
export FILE="$PWD/pom.xml"
export REPO_ROOT="$PWD"

output=$(check_jacoco_config_guard)

[[ "$output" == *"VIOLATION"* ]] \
  || { echo "FAIL: expected VIOLATION in output, got: $output"; exit 1; }
[[ "$output" == *"JaCoCo"* ]] \
  || { echo "FAIL: expected 'JaCoCo' in output, got: $output"; exit 1; }
