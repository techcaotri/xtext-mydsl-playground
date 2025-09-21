package org.xtext.example.mydsl.tests;

import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;
import org.junit.platform.suite.api.SuiteDisplayName;
import org.junit.platform.suite.api.IncludeEngines;

@Suite
@SuiteDisplayName("All Tests")
@SelectPackages("org.xtext.example.mydsl.tests")
@IncludeEngines("junit-jupiter")
public class AllTests {
    // No implementation needed
}
