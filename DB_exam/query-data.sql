-- Find all employees who works in Canada, ordered by last name
SELECT employee_id, first_name, last_name
FROM employees JOIN departments ON employees.department_id=departments.department_id 
               JOIN locations ON departments.location_id=locations.location_id
               JOIN countries ON locations.country_id=countries.country_id
WHERE countries.country_name='Canada'
ORDER BY employees.last_name;

-- Find all countries where does not work any employee
SELECT countries.country_id, countries.country_name
FROM employees JOIN departments ON employees.department_id=departments.department_id 
               JOIN locations ON departments.location_id=locations.location_id
               RIGHT JOIN countries ON locations.country_id=countries.country_id
WHERE locations.location_id IS NULL;

-- Find locations with the highest number of employees
SELECT locations.location_id
FROM employees JOIN departments ON employees.department_id=departments.department_id 
               JOIN locations ON departments.location_id=locations.location_id
GROUP BY locations.location_id
HAVING COUNT(locations.location_id)=(
    SELECT MAX(locations.number_of_employees)
    FROM (
        SELECT COUNT(locations.location_id) number_of_employees
        FROM employees JOIN departments ON employees.department_id=departments.department_id 
                       JOIN locations ON departments.location_id=locations.location_id
        GROUP BY locations.location_id
    ) AS locations
);