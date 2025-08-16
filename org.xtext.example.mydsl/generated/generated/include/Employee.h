// Auto-generated C++ header file

#ifndef EMPLOYEE_H
#define EMPLOYEE_H

// Standard library includes
#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <map>

// Project includes
#include "Person.h"

// Custom includes based on features

namespace com.example {

/**
 * @class Employee
 * @brief An employee entity
 */

class Employee : public Person {
private:
    std::string employeeId;
    double salary = 0.0;
    
    
    
public:
    // Constructors and Destructor
    Employee();
    ~Employee();
    
    
    
    // Public methods
    std::string getEmployeeId() const;
    void setSalary(double value
    );
    void display() const;
    
    // Getters and Setters
    
    
    
    
    
};

} // namespace com.example

// Inline implementations

#endif // EMPLOYEE_H
