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
 * \file ChargeDensity.cpp
 * \brief tiberCAD poisson module implementation.
 *
 * \note This file is part of module poisson.
 */


#include "ChargeDensity.h"
#include "tibercad/module/SimulationInterface.h"

#include "tibercad/module/TiberModule.h"

using namespace std;

void
ChargeDensity::do_init(void)
{
  string chdens_str = get_option("charge_density", "0");
  istringstream is(chdens_str);

  double val;
  if ((is >> val) || (chdens_str[0] == '$'))
  {
     get_parameter("charge_density", _charge_density);
  }
  else
  {
     vector<string> chdens;
     Utils::extract_vector(chdens_str, chdens);
     _charge_density_sim.resize(chdens.size());
     for (size_t i = 0; i < chdens.size(); ++i)
     {
       _charge_density_sim[i] = SimulationInterface::find_solution_provider(chdens[i],"ChargeDensity");

       if (_charge_density_sim[i].first == NULL || 
           _charge_density_sim[i].second == INVALID_ID)
       {

           throw InitFailedException(chdens[i] + " is invalid identifier for "
                  "a module providing ChargeDensity");
       }
    
     }
   }
}


double
ChargeDensity::calculate_charge_density(const Elem* elem, const Point& point)
{
  if (_charge_density_sim.size())
  {
    double value=0.0;
    for(unsigned int i=0; i<_charge_density_sim.size();i++)
    {
       double val_tmp;
       ID id = _charge_density_sim[i].second;
       SimulationInterface* si = _charge_density_sim[i].first;
       si->get_solution(elem,id,val_tmp,point);
       value += val_tmp;
    }
    return value;
  }
  else
  {  
    return _charge_density;
  }
}
