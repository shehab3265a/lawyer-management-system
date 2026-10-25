package com.lawyerapp.service;

import com.lawyerapp.entity.Client;
import com.lawyerapp.exception.ResourceNotFoundException;
import com.lawyerapp.repository.ClientRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ClientService {

    private final ClientRepository clientRepository;

    public ClientService(ClientRepository clientRepository) {
        this.clientRepository = clientRepository;
    }

    public Client createClient(Client client) {
        return clientRepository.save(client);
    }

    public List<Client> getAllClients() {
        return clientRepository.findAll();
    }

    public Client getClientById(Long id) {
        return clientRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Client not found"));
    }

    public Client updateClient(Long id, Client updatedClient) {
        Client client = getClientById(id);

        client.setFullName(updatedClient.getFullName());
        client.setPhone(updatedClient.getPhone());
        client.setEmail(updatedClient.getEmail());
        client.setAddress(updatedClient.getAddress());
        client.setNotes(updatedClient.getNotes());

        return clientRepository.save(client);
    }

    public void deleteClient(Long id) {
        Client client = getClientById(id);
        clientRepository.delete(client);
    }
}