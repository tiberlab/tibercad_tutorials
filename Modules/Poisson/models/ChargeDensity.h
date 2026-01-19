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
 * \file ChargeDensity.h
 * \brief tiberCAD poisson module header.
 *
 * \note This file is part of module poisson.
 */


#ifndef _CONSTANTCHARGEDENSITY_H_
#define _CONSTANTCHARGEDENSITY_H_

#include "ChargeDensityModel.h"
#include "tibercad/module/SolutionProvider.h"

class Elem;
class Point;

// Base class for charge density models
class ChargeDensity : public ChargeDensityModel
{

  public:

    virtual ~ChargeDensity(void) {};

    static ChargeDensity* create(const ModelOptions& options);


  protected:

    ChargeDensity(const ModelOptions& options);

    virtual void do_init(void);

    virtual double calculate_charge_density(const Elem* elem, const Point& point);

  private:

    double _charge_density;
   
    std::vector<SolutionProvider> _charge_density_sim;
};


inline
ChargeDensity::ChargeDensity(const ModelOptions& options) :
  ChargeDensityModel(options),
  _charge_density(0.0)
{
}


inline
ChargeDensity*
ChargeDensity::create(const ModelOptions& options)
{
  ChargeDensity* cd = new ChargeDensity(options);
  std::cout << "Charge Density Created ID: "<< cd->get_id()<< std::endl;

  return cd;

}



#endif // _CHARGEDENSITYMODEL_H_
