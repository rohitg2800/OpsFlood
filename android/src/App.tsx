import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'react-native';
import { HomeScreen } from './screens/HomeScreen';
import { TelemetryScreen } from './screens/TelemetryScreen';

const Tab = createBottomTabNavigator();

export default function App() {
  return (
    <NavigationContainer
      theme={{
        dark: true,
        colors: {
          primary: '#22c55e',
          background: '#060a0e',
          card: '#0d1520',
          text: '#c8d8e8',
          border: '#1a2535',
          notification: '#ff4455',
        },
      }}
    >
      <StatusBar barStyle="light-content" backgroundColor="#060a0e" />
      <Tab.Navigator
        screenOptions={{
          headerShown: false,
          tabBarStyle: {
            backgroundColor: '#0d1520',
            borderTopColor: '#1a2535',
            height: 60,
            paddingBottom: 8,
          },
          tabBarActiveTintColor: '#22c55e',
          tabBarInactiveTintColor: '#4a6070',
          tabBarLabelStyle: { fontSize: 10, fontWeight: '700', letterSpacing: 0.5 },
        }}
      >
        <Tab.Screen
          name="Home"
          component={HomeScreen}
          options={{ tabBarLabel: 'Overview', tabBarIcon: ({ color }) => null }}
        />
        <Tab.Screen
          name="Telemetry"
          component={TelemetryScreen}
          options={{ tabBarLabel: 'Live Feed', tabBarIcon: ({ color }) => null }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
