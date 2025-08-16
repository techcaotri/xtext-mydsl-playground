// Auto-generated C++ header file

#ifndef PERSON_H
#define PERSON_H

// Standard library includes
#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <map>

// Project includes

// Custom includes based on features

namespace com.example {

/**
 * @class Person
 * @brief A person entity
 */

class Person {
private:
    std::string name;
    int age;
    
    
    
public:
    // Constructors and Destructor
    Person();
    Person();
    explicit Person(std::string& name, int age
    );
    virtual ~Person();
    
    
    
    // Public methods
    std::string getName() const;
    void setName(std::string& value
    );
    int getAge() const noexcept;
    virtual void display() const;
    
    // Getters and Setters
    std::string getEmail() const { return email; }
    void setEmail(const std::string& value) { email = value; }
    
    
    
    
    
};

} // namespace com.example

// Inline implementations

#endif // PERSON_H
