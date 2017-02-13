program testpropgators

use assertions
use constants
use ephemerides, only: init_ephemeris
use epochs
use events
use exceptions
use forces, only: thirdbody
use interfaces, only: getstate, gettrajectory
use math, only: eps, pi, twopi, isapprox
use propagators
use states, only: keplerian, period, state
use trajectories
use types, only: dp

implicit none

type(exception) :: err
real(dp) :: mu
real(dp) :: dt
real(dp), dimension(6) :: rv0exp
real(dp), dimension(6) :: rv1exp
real(dp), dimension(6) :: rv0
real(dp), dimension(6) :: rv1
real(dp), dimension(6) :: el
type(kepler) :: kep
type(epoch) :: ep
type(state) :: s0
type(state) :: s1
type(state) :: s1d
type(state) :: s1ds
type(state) :: se
type(epochdelta) :: epd
type(epochdelta) :: epd2
type(trajectory) :: tra
type(ode) :: o

call init_constants
call init_ephemeris

! Source: Vallado, Fundamentals of Astrodynamics and Applications, 4th edition, p. 94-95
mu = 3.986004418e5_dp
rv0exp = [1131.340_dp, -2282.343_dp, 6672.423_dp, -5.64305_dp, 4.30333_dp, 2.42879_dp]
dt = 40._dp * 60._dp
rv1exp = [-4219.752737795695_dp, 4363.029177180833_dp, -3958.7666166029762_dp, &
    3.689866025052519_dp, -1.9167347770873095_dp, -6.112511100000719_dp]
rv1 = solve_kepler(mu, rv0exp, dt)
call assert_almost_equal(rv1, rv1exp, __LINE__)
rv0 = solve_kepler(mu, rv1, -dt)
call assert_almost_equal(rv0, rv0exp, __LINE__)
rv1 = solve_kepler(mu, rv0exp, eps)
call assert_almost_equal(rv1, rv0exp, __LINE__)
rv1 = solve_kepler(mu, rv0exp, dt, iterations=1, err=err)
call assert_raises("Kepler solver did not converge.", err, __LINE__)
call reset(err)

ep = epoch()
s0 = state(ep, rv0exp)
s1 = getstate(s0, dt, kep)
call assert_almost_equal(s1%rv, rv1exp, __LINE__)
epd = epochdelta(seconds=dt)
s1 = getstate(s0, epd, kep)
call assert_almost_equal(s1%rv, rv1exp, __LINE__)
kep = kepler(iterations=1)
s1 = getstate(s0, epd, kep, err=err)
call assert_raises("Kepler solver did not converge.", err, __LINE__)
call reset(err)

kep = kepler()
tra = gettrajectory(s0, epd, kep)
call assert_almost_equal(tra%final_state%rv, rv1exp, __LINE__)

o = ode(maxstep=10._dp)
s1 = getstate(s0, epd, o)
call assert_almost_equal(s1%rv, rv1exp, __LINE__)

tra = gettrajectory(s0, epd, o)
epd2 = epochdelta(seconds=dt/2)
se = getstate(s0, epd2, o)
call assert_false(isdirty(tra), __LINE__)
call assert_almost_equal(tra%final_state%rv, rv1exp, __LINE__)

s1 = getstate(tra, epd2)
call assert_almost_equal(s1%rv, se%rv, __LINE__)

o = ode(maxstep=100._dp, events=[event(detect=pericenter(), abort=.true.)])
s1 = getstate(s0, 86400._dp, o)
el = keplerian(s1)
call assert(isapprox(el(6), 0._dp).or.isapprox(el(6), twopi), __LINE__)

o = ode(maxstep=100._dp, events=[event(detect=apocenter(), abort=.true.)])
s1 = getstate(s0, 86400._dp, o)
el = keplerian(s1)
call assert_almost_equal(el(6), pi, __LINE__)

o = ode(maxstep=100._dp, events=[event(detect=pericenter())])
s1 = getstate(s0, period(s0)*3, o)
call assert_equal(size(o%events(1)%tlog), 3, __LINE__)

o = ode(maxstep=100._dp, events=[event(detect=apocenter())])
s1 = getstate(s0, period(s0)*3, o)
call assert_equal(size(o%events(1)%tlog), 3, __LINE__)

o = ode(maxstep=100._dp, events=[event(detect=apocenter(), numabort=2)])
s1 = getstate(s0, period(s0)*3, o)
call assert_equal(size(o%events(1)%tlog), 2, __LINE__)

s0 = state(ep, [au, 0._dp, 0._dp, 0._dp, 30000._dp, 0._dp], center=sun)
o = ode(maxstep=1._dp, center=sun)
s1ds = getstate(s0, seconds_per_day, o)
s0%rv(4:6) = s0%rv(4:6) * seconds_per_day
o = ode(days=.true., maxstep=1._dp/seconds_per_day)
s1d = getstate(s0, 1._dp, o)
s1d%rv(4:6) = s1d%rv(4:6) / seconds_per_day
call assert_almost_equal(s1ds%rv, s1d%rv, __LINE__, rtol=1e-5_dp)

! Reference value from Orekit
rv1exp = [-4219.7545636149_dp, 4363.0305735489_dp, -3958.767123328_dp, &
    3.689863232_dp, -1.9167326384_dp, -6.1125111597_dp]
ep = epoch(2020, 1, 1)
s0 = state(ep, rv0exp)
o = ode(maxstep=10._dp, tbmodel=thirdbody([moon, sun]))
s1 = getstate(s0, dt, o)
call assert_almost_equal(s1%rv, rv1exp, __LINE__)

end program testpropgators
