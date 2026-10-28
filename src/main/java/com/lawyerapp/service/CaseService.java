
package com.lawyerapp.service;

import com.lawyerapp.entity.Case;
import com.lawyerapp.entity.Client;
import com.lawyerapp.entity.Lawyer;
import com.lawyerapp.exception.ResourceNotFoundException;
import com.lawyerapp.repository.CaseRepository;
import com.lawyerapp.repository.ClientRepository;
import com.lawyerapp.repository.LawyerRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CaseService {

    private final CaseRepository caseRepository;
    private final ClientRepository clientRepository;
    private final LawyerRepository lawyerRepository;

    public CaseService(
            CaseRepository caseRepository,
            ClientRepository clientRepository,
            LawyerRepository lawyerRepository) {
        this.caseRepository = caseRepository;
        this.clientRepository = clientRepository;
        this.lawyerRepository = lawyerRepository;
    }

    public Case createCase(Case legalCase, Long clientId, Long lawyerId) {
        if (caseRepository.existsByCaseNumber(legalCase.getCaseNumber())) {
            throw new IllegalArgumentException("Case number already exists");
        }

        Client client = clientRepository.findById(clientId)
                .orElseThrow(() -> new ResourceNotFoundException("Client not found"));

        Lawyer lawyer = lawyerRepository.findById(lawyerId)
                .orElseThrow(() -> new ResourceNotFoundException("Lawyer not found"));

        legalCase.setClient(client);
        legalCase.setLawyer(lawyer);

        return caseRepository.save(legalCase);
    }

    public List<Case> getAllCases() {
        return caseRepository.findAll();
    }

    public Case getCaseById(Long id) {
        return caseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Case not found"));
    }

    public Case updateCase(
            Long id,
            Case updatedCase,
            Long clientId,
            Long lawyerId) {
        Case legalCase = getCaseById(id);

        boolean duplicateCaseNumber =
                caseRepository.existsByCaseNumber(updatedCase.getCaseNumber())
                && !legalCase.getCaseNumber().equals(updatedCase.getCaseNumber());

        if (duplicateCaseNumber) {
            throw new IllegalArgumentException("Case number already exists");
        }

        Client client = clientRepository.findById(clientId)
                .orElseThrow(() -> new ResourceNotFoundException("Client not found"));

        Lawyer lawyer = lawyerRepository.findById(lawyerId)
                .orElseThrow(() -> new ResourceNotFoundException("Lawyer not found"));

        legalCase.setCaseNumber(updatedCase.getCaseNumber());
        legalCase.setTitle(updatedCase.getTitle());
        legalCase.setCourtName(updatedCase.getCourtName());
        legalCase.setCaseType(updatedCase.getCaseType());
        legalCase.setStatus(updatedCase.getStatus());
        legalCase.setStartDate(updatedCase.getStartDate());
        legalCase.setNextHearingDate(updatedCase.getNextHearingDate());
        legalCase.setNotes(updatedCase.getNotes());
        legalCase.setDescription(updatedCase.getDescription());
        legalCase.setClient(client);
        legalCase.setLawyer(lawyer);

        return caseRepository.save(legalCase);
    }

    public void deleteCase(Long id) {
        Case legalCase = getCaseById(id);
        caseRepository.delete(legalCase);
    }
}
