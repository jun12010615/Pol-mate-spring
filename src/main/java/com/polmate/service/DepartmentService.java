package com.polmate.service;

import com.polmate.entity.Department;
import com.polmate.repository.DepartmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DepartmentService {

    private final DepartmentRepository deptRepo;

    public List<Map<String, Object>> getByOrg(String orgName) {
        return deptRepo.findByOrgNameOrderByDeptName(orgName).stream()
            .map(d -> Map.<String, Object>of("dept_id", d.getDeptId(), "dept_name", d.getDeptName()))
            .collect(Collectors.toList());
    }

    public List<Department> findAll() {
        return deptRepo.findAll();
    }
}
