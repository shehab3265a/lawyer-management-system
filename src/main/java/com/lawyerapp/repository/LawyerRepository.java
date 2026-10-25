
package com.lawyerapp.repository;

import com.lawyerapp.entity.Lawyer;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface LawyerRepository extends JpaRepository<Lawyer, Long> {

    boolean existsByEmail(String email);

    Optional<Lawyer> findByEmail(String email);
}
