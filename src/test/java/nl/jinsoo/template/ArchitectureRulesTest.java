package nl.jinsoo.template;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;
import static org.assertj.core.api.Assertions.assertThat;

import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.domain.JavaPackage;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import java.util.LinkedHashMap;
import java.util.Map;
import org.jspecify.annotations.NullMarked;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.data.jdbc.test.autoconfigure.DataJdbcTest;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.modulith.test.ApplicationModuleTest;
import org.springframework.transaction.annotation.Transactional;

class ArchitectureRulesTest {

  private final JavaClasses classes =
      new ClassFileImporter()
          .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
          .importPackages("nl.jinsoo.template");

  private final JavaClasses testClasses =
      new ClassFileImporter()
          .withImportOption(location -> location.contains("/test-classes/"))
          .importPackages("nl.jinsoo.template");

  @Test
  void noJpaImports() {
    noClasses()
        .should()
        .dependOnClassesThat()
        .resideInAnyPackage("jakarta.persistence..", "javax.persistence..")
        .check(classes);
  }

  @Test
  void noFieldInjection() {
    noFields()
        .should()
        .beAnnotatedWith(Autowired.class)
        .orShould()
        .beAnnotatedWith(Value.class)
        .allowEmptyShould(true)
        .check(classes);
  }

  @Test
  void internalClassesShouldBePackagePrivate() {
    classes()
        .that()
        .resideInAPackage("..internal..")
        .and()
        .areNotInterfaces()
        .should()
        .notBePublic()
        .allowEmptyShould(true)
        .check(classes);
  }

  @Test
  void allPackagesMustBeNullMarked() {
    Map<String, JavaPackage> packages = new LinkedHashMap<>();
    for (JavaClass cls : classes) {
      packages.putIfAbsent(cls.getPackageName(), cls.getPackage());
    }
    assertThat(packages).isNotEmpty();
    packages.forEach(
        (name, pkg) ->
            assertThat(pkg.isAnnotatedWith(NullMarked.class))
                .as("Package %s must have @NullMarked in package-info.java", name)
                .isTrue());
  }

  @Test
  void useCasesMustNotHaveTransactionalMethods() {
    noMethods()
        .that()
        .areDeclaredInClassesThat()
        .haveSimpleNameEndingWith("UseCase")
        .should()
        .beAnnotatedWith(Transactional.class)
        .allowEmptyShould(true)
        .check(classes);
  }

  @Test
  void moduleApiImplementationsMustHaveTransactionalMethods() {
    methods()
        .that()
        .arePublic()
        .and()
        .areDeclaredInClassesThat()
        .implement(JavaClass.Predicates.simpleNameEndingWith("API"))
        .and()
        .areDeclaredInClassesThat()
        .areNotInterfaces()
        .should()
        .beAnnotatedWith(Transactional.class)
        .allowEmptyShould(true)
        .check(classes);
  }

  @Test
  void randomPortTestsMustBeNamedIT() {
    classes()
        .that(haveSpringBootTestWithRandomPort())
        .should()
        .haveSimpleNameEndingWith("IT")
        .allowEmptyShould(true)
        .check(testClasses);
  }

  @Test
  void sliceAndModuleTestsMustNotBeNamedIT() {
    noClasses()
        .that()
        .haveSimpleNameEndingWith("IT")
        .should()
        .beAnnotatedWith(DataJdbcTest.class)
        .orShould()
        .beAnnotatedWith(WebMvcTest.class)
        .orShould()
        .beAnnotatedWith(ApplicationModuleTest.class)
        .allowEmptyShould(true)
        .check(testClasses);
  }

  private static DescribedPredicate<JavaClass> haveSpringBootTestWithRandomPort() {
    return new DescribedPredicate<>("are annotated with @SpringBootTest(RANDOM_PORT)") {
      @Override
      public boolean test(JavaClass cls) {
        return cls.isAnnotatedWith(SpringBootTest.class)
            && cls.getAnnotationOfType(SpringBootTest.class).webEnvironment()
                == SpringBootTest.WebEnvironment.RANDOM_PORT;
      }
    };
  }
}
