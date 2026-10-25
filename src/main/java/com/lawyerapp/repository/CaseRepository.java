package com.lawyerapp.repository;

import com.lawyerapp.entity.Case;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CaseRepository extends JpaRepository<Case, Long> {
    boolean existsByCaseNumber(String caseNumber);
}