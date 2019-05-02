% main

clear all
close all

%% select task and robot to be loaded
taskSelection = 'speedyStairs';
robotSelection = 'speedy';

%% get suggested removal ratio for cropping motion data to useful steady state motion

[removalRatioStart, removalRatioEnd] = getSuggestedRemovalRatios(taskSelection);

%% load motion and force data
% universalTrot
% universalStairs
% speedyGallop
% speedyStairs
% massivoWalk
% massivoStairs
% centaurWalk
% centaurStairs
% miniPronk

load(taskSelection);

%% load corresponding robot parameters
% universal
% speedy
% massivo
% centaur
% mini

quadruped = getQuadrupedProperties(robotSelection);

%% get the relative motion of the end effectors to the hips
[relativeMotionHipEE, IF_hip] = getRelativeMotionEEHips(quat, quadruped, base, EE);

%% get the liftoff and touchdown timings for each end effector
[tLiftoff, tTouchdown, minStepCount] = getEELiftoffTouchdownTimings(t, EE);

%% get the mean cyclic position and forces
[meanCyclicMotionHipEE, cyclicMotionHipEE, samplingStart, samplingEnd] = getHipEECyclicData(tLiftoff, tTouchdown, relativeMotionHipEE, EE, removalRatioStart, removalRatioEnd, dt, minStepCount);

%% plot data
plotMotionData;