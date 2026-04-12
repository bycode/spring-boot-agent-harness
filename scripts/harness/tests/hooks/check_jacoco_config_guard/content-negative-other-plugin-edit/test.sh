#!/usr/bin/env bash
# Content-negative: modify a line inside a different <plugin> (spotless) —
# the guard must stay silent because the change does not touch the jacoco
# block or any jacoco-tagged line.
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

# Bump the spotless plugin version — unrelated to jacoco.
sed -i.bak 's|<version>3.4.0</version>|<version>3.5.0</version>|' pom.xml
rm -f pom.xml.bak

export TOOL=Edit
export FILE="$PWD/pom.xml"
export REPO_ROOT="$PWD"

output=$(check_jacoco_config_guard)

[[ -z "$output" ]] \
  || { echo "FAIL: expected empty output, got: $output"; exit 1; }
