
package com.lawyerapp.auth;

import com.lawyerapp.entity.Lawyer;
import com.lawyerapp.repository.LawyerRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final LawyerRepository lawyerRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthController(
            LawyerRepository lawyerRepository,
            PasswordEncoder passwordEncoder) {
        this.lawyerRepository = lawyerRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> request) {
        String email = request.get("email");
        String password = request.get("password");

        if (email == null || password == null) {
            return ResponseEntity.badRequest()
                    .body(Map.of("message", "Email and password are required"));
        }

        Lawyer lawyer = lawyerRepository.findByEmail(email.trim())
                .orElse(null);

        if (lawyer == null || !passwordEncoder.matches(password, lawyer.getPassword())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", "Invalid email or password"));
        }

        return ResponseEntity.ok(Map.of(
                "message", "Login successful",
                "lawyerId", lawyer.getId(),
                "fullName", lawyer.getFullName(),
                "email", lawyer.getEmail()
        ));
    }
}
