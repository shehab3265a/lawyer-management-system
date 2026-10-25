
package com.lawyerapp.service;

import com.lawyerapp.entity.Appointment;
import com.lawyerapp.entity.Case;
import com.lawyerapp.exception.ResourceNotFoundException;
import com.lawyerapp.repository.AppointmentRepository;
import com.lawyerapp.repository.CaseRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AppointmentService {

    private final AppointmentRepository appointmentRepository;
    private final CaseRepository caseRepository;

    public AppointmentService(
            AppointmentRepository appointmentRepository,
            CaseRepository caseRepository) {
        this.appointmentRepository = appointmentRepository;
        this.caseRepository = caseRepository;
    }

    public Appointment createAppointment(Appointment appointment, Long caseId) {
        if (caseId != null) {
            Case legalCase = caseRepository.findById(caseId)
                    .orElseThrow(() -> new ResourceNotFoundException("Case not found"));
            appointment.setLegalCase(legalCase);
        }

        return appointmentRepository.save(appointment);
    }

    public List<Appointment> getAllAppointments() {
        return appointmentRepository.findAll();
    }

    public Appointment getAppointmentById(Long id) {
        return appointmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found"));
    }

    public Appointment updateAppointment(
            Long id, Appointment updatedAppointment, Long caseId) {
        Appointment appointment = getAppointmentById(id);

        appointment.setTitle(updatedAppointment.getTitle());
        appointment.setDescription(updatedAppointment.getDescription());
        appointment.setAppointmentDate(updatedAppointment.getAppointmentDate());
        appointment.setAppointmentTime(updatedAppointment.getAppointmentTime());
        appointment.setLocation(updatedAppointment.getLocation());
        appointment.setStatus(updatedAppointment.getStatus());

        if (caseId != null) {
            Case legalCase = caseRepository.findById(caseId)
                    .orElseThrow(() -> new ResourceNotFoundException("Case not found"));
            appointment.setLegalCase(legalCase);
        } else {
            appointment.setLegalCase(null);
        }

        return appointmentRepository.save(appointment);
    }

    public void deleteAppointment(Long id) {
        Appointment appointment = getAppointmentById(id);
        appointmentRepository.delete(appointment);
    }
}
