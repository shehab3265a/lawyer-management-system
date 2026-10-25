package com.lawyerapp.controller;

import org.springframework.http.HttpStatus;
import jakarta.validation.Valid;
import com.lawyerapp.entity.Lawyer;
import com.lawyerapp.service.LawyerService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/lawyers")
public class LawyerController {

    private final LawyerService lawyerService;

    public LawyerController(LawyerService lawyerService) {
        this.lawyerService = lawyerService;
    }

@PostMapping
@ResponseStatus(HttpStatus.CREATED)
public Lawyer createLawyer(@Valid @RequestBody Lawyer lawyer) {
    return lawyerService.createLawyer(lawyer);
}

    @GetMapping
    public List<Lawyer> getAllLawyers() {
        return lawyerService.getAllLawyers();
    }

    @GetMapping("/{id}")
    public Lawyer getLawyerById(@PathVariable Long id) {
        return lawyerService.getLawyerById(id);
    }

    @DeleteMapping("/{id}")
    public void deleteLawyer(@PathVariable Long id) {
        lawyerService.deleteLawyer(id);
    }
}