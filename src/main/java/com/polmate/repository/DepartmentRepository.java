package com.polmate.repository;

import com.polmate.entity.Department;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DepartmentRepository extends JpaRepository<Department, Integer> {

    List<Department> findByOrgNameOrderByDeptName(String orgName);
}
