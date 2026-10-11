package org.eclipse.cargotracker.domain.shared;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Specification Tests")
class SpecificationTest {

    // Concrete implementation for testing
    static class AlwaysTrueSpec extends AbstractSpecification<String> {
        @Override
        public boolean isSatisfiedBy(String s) {
            return true;
        }
    }

    static class AlwaysFalseSpec extends AbstractSpecification<String> {
        @Override
        public boolean isSatisfiedBy(String s) {
            return false;
        }
    }

    static class ContainsASpec extends AbstractSpecification<String> {
        @Override
        public boolean isSatisfiedBy(String s) {
            return s != null && s.contains("A");
        }
    }

    @Test
    @DisplayName("AndSpecification returns true when both specs are satisfied")
    void andSpecification_bothSatisfied_returnsTrue() {
        Specification<String> spec = new AlwaysTrueSpec().and(new AlwaysTrueSpec());
        assertTrue(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("AndSpecification returns false when first spec is not satisfied")
    void andSpecification_firstNotSatisfied_returnsFalse() {
        Specification<String> spec = new AlwaysFalseSpec().and(new AlwaysTrueSpec());
        assertFalse(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("AndSpecification returns false when second spec is not satisfied")
    void andSpecification_secondNotSatisfied_returnsFalse() {
        Specification<String> spec = new AlwaysTrueSpec().and(new AlwaysFalseSpec());
        assertFalse(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("AndSpecification returns false when both specs are not satisfied")
    void andSpecification_neitherSatisfied_returnsFalse() {
        Specification<String> spec = new AlwaysFalseSpec().and(new AlwaysFalseSpec());
        assertFalse(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("OrSpecification returns true when first spec is satisfied")
    void orSpecification_firstSatisfied_returnsTrue() {
        Specification<String> spec = new AlwaysTrueSpec().or(new AlwaysFalseSpec());
        assertTrue(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("OrSpecification returns true when second spec is satisfied")
    void orSpecification_secondSatisfied_returnsTrue() {
        Specification<String> spec = new AlwaysFalseSpec().or(new AlwaysTrueSpec());
        assertTrue(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("OrSpecification returns false when neither spec is satisfied")
    void orSpecification_neitherSatisfied_returnsFalse() {
        Specification<String> spec = new AlwaysFalseSpec().or(new AlwaysFalseSpec());
        assertFalse(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("NotSpecification returns false when spec is satisfied")
    void notSpecification_specSatisfied_returnsFalse() {
        Specification<String> spec = new AlwaysTrueSpec().not(new AlwaysTrueSpec());
        assertFalse(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("NotSpecification returns true when spec is not satisfied")
    void notSpecification_specNotSatisfied_returnsTrue() {
        Specification<String> spec = new AlwaysTrueSpec().not(new AlwaysFalseSpec());
        assertTrue(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("AndSpecification with concrete spec works correctly")
    void andSpecification_withConcreteSpec_worksCorrectly() {
        Specification<String> spec = new ContainsASpec().and(new AlwaysTrueSpec());
        assertTrue(spec.isSatisfiedBy("ABC"));
        assertFalse(spec.isSatisfiedBy("XYZ"));
    }

    @Test
    @DisplayName("OrSpecification with concrete spec works correctly")
    void orSpecification_withConcreteSpec_worksCorrectly() {
        Specification<String> spec = new ContainsASpec().or(new AlwaysFalseSpec());
        assertTrue(spec.isSatisfiedBy("ABC"));
        assertFalse(spec.isSatisfiedBy("XYZ"));
    }

    @Test
    @DisplayName("Direct AndSpecification constructor works")
    void andSpecification_directConstructor_works() {
        AndSpecification<String> spec = new AndSpecification<>(new AlwaysTrueSpec(), new AlwaysTrueSpec());
        assertTrue(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("Direct OrSpecification constructor works")
    void orSpecification_directConstructor_works() {
        OrSpecification<String> spec = new OrSpecification<>(new AlwaysTrueSpec(), new AlwaysFalseSpec());
        assertTrue(spec.isSatisfiedBy("test"));
    }

    @Test
    @DisplayName("Direct NotSpecification constructor works")
    void notSpecification_directConstructor_works() {
        NotSpecification<String> spec = new NotSpecification<>(new AlwaysTrueSpec());
        assertFalse(spec.isSatisfiedBy("test"));
    }
}
