
package com.lawyerapp.controller;

import com.lawyerapp.entity.Case;
import com.lawyerapp.service.CaseService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/cases")
public class CaseController {

    private final CaseService caseService;

    public CaseController(CaseService caseService) {
        this.caseService = caseService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Case createCase(
            @RequestParam Long clientId,
            @RequestParam Long lawyerId,
            @Valid @RequestBody Case legalCase) {
        return caseService.createCase(legalCase, clientId, lawyerId);
    }

    @GetMapping
    public List<Case> getAllCases() {
        return caseService.getAllCases();
    }

    @GetMapping("/{id}")
    public Case getCaseById(@PathVariable Long id) {
        return caseService.getCaseById(id);
    }

    @PutMapping("/{id}")
    public Case updateCase(
            @PathVariable Long id,
            @RequestParam Long clientId,
            @RequestParam Long lawyerId,
            @Valid @RequestBody Case legalCase) {
        return caseService.updateCase(id, legalCase, clientId, lawyerId);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCase(@PathVariable Long id) {
        caseService.deleteCase(id);
    }
}
