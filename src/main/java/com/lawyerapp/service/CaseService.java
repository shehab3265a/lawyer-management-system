
package com.lawyerapp.service;

import com.lawyerapp.entity.Case;
import com.lawyerapp.entity.Client;
import com.lawyerapp.exception.ResourceNotFoundException;
import com.lawyerapp.repository.CaseRepository;
import com.lawyerapp.repository.ClientRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CaseService {

    private final CaseRepository caseRepository;
    private final ClientRepository clientRepository;

    public CaseService(
            CaseRepository caseRepository,
            ClientRepository clientRepository) {
        this.caseRepository = caseRepository;
        this.clientRepository = clientRepository;
    }

    public Case createCase(Case legalCase, Long clientId) {
        if (caseRepository.existsByCaseNumber(legalCase.getCaseNumber())) {
            throw new IllegalArgumentException("Case number already exists");
        }

        Client client = clientRepository.findById(clientId)
                .orElseThrow(() -> new ResourceNotFoundException("Client not found"));

        legalCase.setClient(client);

        return caseRepository.save(legalCase);
    }

    public List<Case> getAllCases() {
        return caseRepository.findAll();
    }

    public Case getCaseById(Long id) {
        return caseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Case not found"));
    }

    public Case updateCase(Long id, Case updatedCase, Long clientId) {
        Case legalCase = getCaseById(id);

        boolean duplicateCaseNumber = caseRepository.existsByCaseNumber(updatedCase.getCaseNumber())
                && !legalCase.getCaseNumber().equals(updatedCase.getCaseNumber());

        if (duplicateCaseNumber) {
            throw new IllegalArgumentException("Case number already exists");
        }

        Client client = clientRepository.findById(clientId)
                .orElseThrow(() -> new ResourceNotFoundException("Client not found"));

        legalCase.setCaseNumber(updatedCase.getCaseNumber());
        legalCase.setTitle(updatedCase.getTitle());
        legalCase.setCourtName(updatedCase.getCourtName());
        legalCase.setCaseType(updatedCase.getCaseType());
        legalCase.setStatus(updatedCase.getStatus());
        legalCase.setStartDate(updatedCase.getStartDate());
        legalCase.setNextHearingDate(updatedCase.getNextHearingDate());
        legalCase.setNotes(updatedCase.getNotes());
        legalCase.setClient(client);

        return caseRepository.save(legalCase);
    }

    public void deleteCase(Long id) {
        Case legalCase = getCaseById(id);
        caseRepository.delete(legalCase);
    }
}
