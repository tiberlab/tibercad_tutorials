/*  
 * This file is part of the tiberCAD module poisson.
 *
 * tiberCAD modules are licensed under the GNU General Public License v3.
 *
 * tiberCAD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * tiberCAD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with tiberCAD. If not, see <http://www.gnu.org/licenses/>.
 */

/*!
 * \file PoissonDirichlet.cpp
 * \brief tiberCAD poisson module implementation.
 *
 * \note This file is part of module poisson.
 */


#include "PoissonDirichlet.h"

#include "tibercad/module/TiberModule.h"
#include "tibercad/module/SimulationInterface.h"

using namespace std;
using namespace libMesh;


void
PoissonDirichlet::do_init(void)
{
  string str = get_option("potential", "0");
  istringstream is(str);

  double val;
  if ((is >> val) || (str[0] == '$'))
  {
     get_parameter("potential", _potential);
  }
  else
  {
     vector<string> pot;
     Utils::extract_vector(str, pot);
     _sim.resize(1);
     _sim[0] = SimulationInterface::find_solution_provider(pot[0],"ElPotential");

     if (_sim[0].first == NULL || _sim[0].second == INVALID_ID)
     {
         throw InitFailedException(pot[0] + " is invalid identifier for "
                "a module providing ElPotential");
     }
  }
}


void
PoissonDirichlet::calculate(const Elem* elem, unsigned int side,
    const Point& point)
{
  if (_sim.size() > 0)
  {
     ID id = _sim[0].second;
     SimulationInterface* si = _sim[0].first;
     si->get_solution(elem, id, _potential, point);
  }
  
  set_coefficients(1, 0, _potential);
}
