package com.lawyerapp.service;

import com.lawyerapp.exception.ResourceNotFoundException;
import com.lawyerapp.entity.Lawyer;
import com.lawyerapp.repository.LawyerRepository;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class LawyerService {

    private final LawyerRepository lawyerRepository;
    private final BCryptPasswordEncoder passwordEncoder;

    public LawyerService(LawyerRepository lawyerRepository) {
        this.lawyerRepository = lawyerRepository;
        this.passwordEncoder = new BCryptPasswordEncoder();
    }

    public Lawyer createLawyer(Lawyer lawyer) {
        if (lawyerRepository.existsByEmail(lawyer.getEmail())) {
            throw new IllegalArgumentException("Email already exists");
        }

        lawyer.setPassword(passwordEncoder.encode(lawyer.getPassword()));
        return lawyerRepository.save(lawyer);
    }

    public List<Lawyer> getAllLawyers() {
        return lawyerRepository.findAll();
    }

    public Lawyer getLawyerById(Long id) {
        return lawyerRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Lawyer not found"));
    }

    public void deleteLawyer(Long id) {
        if (!lawyerRepository.existsById(id)) {
            throw new ResourceNotFoundException("Lawyer not found");
        }

        lawyerRepository.deleteById(id);
    }
}